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

    def self.init(cfg)
      @@oml_server = cfg[:oml_server] || DEF_OML_SERVER
      @@db_server_prefix = cfg[:db_server] || DEF_DB_SERVER
    end


    oproperty :creation, DataMapper::Property::Time
    oproperty :description, String
    oproperty :priority, Integer
    oproperty :slice, String
    oproperty :oedl_script, String
    oproperty :ec_properties, Object, functional: false, set_filter: :filter_ec_property
    oproperty :oml_db, String
    #oproperty :start_time, Date
    oproperty :start_time, Time
    oproperty :end_time, Time
    oproperty :exit_code, Integer
    oproperty :status, String
    oproperty :user, :user, inverse: :jobs

    def initialize(opts)
      super
      self.creation = Time.now
      self.status = :pending
      # TODO: Make this configurable
      self.oml_db = "#{@@db_server_prefix}/#{self.name}"

      #EM.next_tick { run }
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

    def to_hash_brief(opts = {})
      h = super
      h[:status] = self.status
      h[:oml_db] = self.oml_db
      h
    end

    def run(&post_run_block)
      script_file = Tempfile.new("ec_job_#{self.name}")
      s = Zlib::Inflate.inflate(Base64.decode64(self.oedl_script['content'].join("\n")))
      script_file.write(s)
      script_file.close

      # Build experiment option line
      opts = self.ec_properties.map do |e|
        "--#{e.name} #{e.resource? ? e.resource_name : e.value}"
      end
      # Put together the command line and return
      cmd = "env -i #{EC_PATH} -e #{self.name} --oml_uri #{oml_server} #{script_file.path} -- #{opts.join(' ')}"
      debug "Executing '#{cmd}'"
      self.start_time = Time.now
      OMF::Base::ExecApp.new(self.name, cmd) do |event, id, msg|
        if event == 'EXIT'
          ex_c = msg.to_i
          debug "Experiment '#{self.name}' finished with exit code '#{ex_c}'"
          self.status = (ex_c == 0) ? :finished : :failed
          self.exit_code = ex_c
          self.end_time = Time.now
          self.save
          script_file.unlink
          post_run_block.call() if post_run_block
        end
        #puts "EXEC: #{event}:#{event.class} - #{msg}"
      end
      self.status = :running
      save
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
