require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'
require 'tempfile'
require "zlib"
require 'base64'

module OMF::JobService::Resource

  # This class represents a job in the system.
  #
  class Job < OMF::SFA::Resource::OResource
    EC_PATH = File.absolute_path(File.join(File.dirname(__FILE__), '../../../../omf_ec/omf_ec'))
    raise "Can't find executable 'omf_ec' - #{EC_PATH}" unless File.executable?(EC_PATH)

    DEF_OML_SERVER = 'tcp:localhost:3004'
    DEF_DB_SERVER = 'postgres://oml:oml_nictaNPC@srv.mytestbed.net'

    @@log_file_dir = nil # If set, write all logging output into a file there

    def self.init(cfg)
      @@oml_server = cfg[:oml_server] || DEF_OML_SERVER
      @@db_server_prefix = cfg[:db_server] || DEF_DB_SERVER
      @@log_file_dir = cfg[:log_file_dir]
    end

    def self.log_file_dir
      @@log_file_dir
    end


    oproperty :creation, DataMapper::Property::Time
    oproperty :description, String
    oproperty :priority, Integer
    oproperty :slice, String
    oproperty :oedl_script, String
    oproperty :ec_properties, Object, functional: false, set_filter: :filter_ec_property
    oproperty :oml_db, String
    #oproperty :start_time, Date
    oproperty :requested_time, Time
    oproperty :start_time, Time
    oproperty :end_time, Time
    oproperty :pid, Integer
    oproperty :exit_code, Integer
    oproperty :status, String, set_filter: :filter_status
    oproperty :message, String
    #oproperty :user, :user, inverse: :jobs
    oproperty :username, String
    #oproperty :measurement_points, OMF::JobService::Resource::MeasurementPoint, functional: false
    oproperty :measurement_points, :measurement_point, functional: false
    oproperty :verifications, :verification, functional: false
    oproperty :r_scripts, Hash
    oproperty :slice_service, String
    oproperty :irods_path, String

    oproperty :assertion, String

    def initialize(opts)
      super
      self.creation = Time.now
      self.status = :pending
      self.oml_db = "#{@@db_server_prefix}/#{self.name}"
      self.requested_time = Time.now
      # Verify execution
      self.verifications = [OMF::JobService::Resource::Verification.new(oml_db: self.oml_db, job: self)]
    end

    def filter_ec_property(val)
      unless val.is_a? EcProperty
        val = EcProperty.new(val)
        val.job = self

        begin
          val.save
        rescue Exception => ex
          puts "ERROR: Can't save - #{ex.resource.errors.inspect} - #{ex.resource.errors.full_messages}"
          raise ex
        end
      end
      val
    end

    def filter_status(val)
      #puts "STATUS: #{val}:#{val.class} - #{self.status}:#{status.class}"
      if val == 'aborted'
        status = self.status
        unless ['pending', 'running'].include? status
          return nil # Nothing to abort anymore
        end
        if pid = self.pid
            EM.next_tick { Process.kill("TERM", -1 * self.pid) }
        end
        'aborted'
      end
      val
    end

    def abort_job
      self.status = 'aborted'
    end

    def to_hash_brief(opts = {})
      h = super
      h[:status] = self.status
      h[:oml_db] = self.oml_db
      h[:irods_path] = self.irods_path
      h[:username] = self.username

      if fn = log_file_name()
        if File.readable?(fn)
          # TODO This is no the cleanest solution, but it works
          h[:log_file] = "#{"http://#{Thread.current[:http_host]}"}/logs/#{File.basename(log_file_name)}"
        end
      end
      h
    end


    def log_file_name
      return nil unless @@log_file_dir
      "#{@@log_file_dir}/#{self.uuid}.log"
    end

    def run(&post_run_block)
      return unless self.status == 'pending'

      if self.oedl_script.nil? || self.oedl_script['content'].empty? || self.oedl_script['content'].nil?
        msg = "Cannot run experiment '#{self.name}', there is no OEDL script associated to this job."
        warn msg
        self.status = :failed
        self.message = msg
        save
        return
      end
      script_file = Tempfile.new("ec_job_#{self.name}")
      s = Zlib::Inflate.inflate(Base64.decode64(self.oedl_script['content'].join("\n")))
      script_file.write(s)
      script_file.close

      # Assertion
      if self.assertion
        assertion_file = Tempfile.new("ec_assertion_#{self.name}")
        assertion_file.write(Base64.decode64(self.assertion))
        assertion_file.close
      end

      # Build experiment option line
      opts = self.ec_properties.map do |e|
        "--#{e.name} #{e.resource? ? e.resource_name : e.value}"
      end
      # Put together the command line and return
      cmd = "env -i #{EC_PATH}"
      cmd << " --slice-service #{self.slice_service}" if self.slice_service
      cmd << " --assertion #{assertion_file.path}" if self.assertion
      cmd << " --experiment #{self.name} --oml_uri #{oml_server} "
      cmd << " --slice #{self.slice}" if self.slice
      cmd << " --job-url #{self.href} #{script_file.path} -- #{opts.join(' ')}"

      debug "Executing '#{cmd}'"
      log_file_name = log_file_name()
      log_file = log_file_name ? File.new(log_file_name, 'w') : nil
      self.start_time = Time.now
      app = OMF::Base::ExecApp.new(self.name, cmd) do |event, id, msg|
        monitor_app_event(event, msg)
        if log_file
          log_file.puts("#{event}: #{msg}")
          log_file.flush # for debugging we want this quickly
        else
          debug "ec:#{self.name} #{event}: #{msg}"
        end
        if event == 'EXIT'
          self.reload # could be out of date by now
          ex_c = msg.to_i
          debug "Experiment '#{self.name}' finished with exit code '#{ex_c}' - #{self.status}"

          unless self.status == 'aborted'
            self.status = (ex_c == 0) ? :finished : :failed
          end
          self.exit_code = ex_c
          self.end_time = Time.now
          self.save
          script_file.unlink
          post_run_block.call() if post_run_block
          log_file.close if log_file
        end
      end
      self.pid = app.pid
      self.status = :running
      save
    end

    def monitor_app_event(event, msg)
      return unless event == 'STDOUT'
      if (m = msg.match(/: REPORT:([A-Za-z:]*)\s*(.*)/))
        debug "graph_description: #{m[1]} -- #{m[2]}"
        case m[1]
        when /START:/
          error "Unfinished graph description detected - #{@gd}" if @gd
          @gd = {job: self, oml_db: self.oml_db, name: (m[2] || 'unknown').strip.downcase}
        when /CAPTION:/
          @gd[:caption] = URI.decode(m[2])
        when /MS:/
          @gd[:name] = @gd[:name] + ':' + m[1].split(':')[1]
          @gd[:sql] = URI.decode(m[2])
        when /STOP/
          begin
            ms = OMF::JobService::Resource::MeasurementPoint.new(@gd)
            self.reload # could be out of date by now
            self.measurement_points << ms
            self.save
          rescue => ex
            warn "While creating measurement point - #{ex}"
          end
          @gd = nil
        end
      end
    end

    def oml_server
      @@oml_server
    end

    def resources
      self.ec_properties.select {|e| e.resource? }
    end

   def assign_resource(name, res_name)
     self.ec_properties.each do |e|
       if e.resource? && e.name == name
         e.resource_name = res_name
         e.save
       end
     end
     save
   end
  end # classs
end # module
