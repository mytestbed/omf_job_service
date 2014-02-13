
require 'omf_base/lobject'
require 'omf_base/exec_app'
require 'digest/sha1'


module OMF::JobService
  module Scheduler

    class SimpleScheduler < OMF::Base::LObject

      POLL_PERIOD = 5 # period in second when the scheduler should wake up
      ED_PATH = "/tmp/"
      # TODO: I had some path issues to find the local EC install within
      # ExecApp... This is ugly now, but I needed something to work today
      # and fighting with paths was not a priority today. But this has to
      # be fixed very soon!
      EC_PATH = "/home/ubuntu/omf_job_service/omf_ec/omf_ec"
      # TODO: In this simple scheduler this is how we defined the initial
      # list of available resources and their types. We should soon move 
      # towards something more dynamic!
      SUPPORTED_RESOURCE_TYPES = [ :node ]
      @@available_resources = ['00121', 'wlan-0a118113.ipt.nicta.com.au']
      @@started = false
      @@running_jobs = []

      def start
        return if @@started
        EM.add_periodic_timer(POLL_PERIOD) do

          # DEBUG ONLY
          #all_jobs = OMF::JobService::Resource::Job.all()
          #all_jobs.each { |j| debug ">>> Job - '#{j.name}' - '#{j.status}'" }
          #debug ">>> available resource: #{@@available_resources}"

          # refresh the list of pending jobs from the database
          pending_jobs = OMF::JobService::Resource::Job.prop_all(status: 'pending')
          unless pending_jobs.empty?
            # Refresh the list of available resources
            # TODO: in this simple example, for now just get a test list of known fixed resources
            # (some more code to be placed here to get the list of available resource!)
            res  = @@available_resources
            schedule(res, pending_jobs.first)
          end
        end
        @@started = true
      end

      def on_new_job(job)
        warn "Received new job '#{job}'"
        start 
      end

      def supported_types?(t)
        # TODO: put some more fancy checking here in the future
        # Potentially by querying some external module or entity?
        SUPPORTED_RESOURCE_TYPES.include?(t)  
      end
      
      def schedule(resources, job)
        return if resources.empty? || job.nil?
        # Extract the resource requirements for this job
        res_req = []
        job.ec_properties.each do |e|
          unless (rd = e.value["resource"]).nil?
            type = rd[:type] || rd['type']
            unless type.nil?
              if supported_types?(type.downcase.to_sym)
                res_req << {:name => e.value["name"] , :type => type, :assigned_to => nil}
              else
                warn "Job '#{job.name}' requests a resource of type '#{type}', which is not supported by this scheduler"
              end
            end
          end
        end
        # debug ">>> Resource Requested -  #{res_req.inspect}"

        # Determine if there are enough free resources to run this job now
        # If so, then run the job and mark it accordingly, do nothing otherwise
        if res_req.length <= @@available_resources.length
          # Assign the first available resources to this job
          res_alloc = alloc_resource(res_req)
          info "Running job '#{job.name}' with resource(s) #{res_alloc.to_s}"
          # Start the job
          cmd = build_job_cmd(job, res_alloc)
          #debug ">>> Job Command line: '#{cmd}'"
          OMF::Base::ExecApp.new(job.name, cmd) { |event, id, msg| on_job_event(job, res_alloc, event, id, msg) }
          job.status = :running
        end
      end

      def on_job_event(job, res_alloc, event, id, msg)
        info "Job '#{id}' - Event '#{event}' : #{msg}"
        # When the job is completed, mark it so and deallocate its resources
        if event.downcase.to_sym == :exit
          job.status = :completed 
          dealloc_resource(res_alloc)
        end
      end 

      def alloc_resource(request)
        request.each_index do |i|
          request[i][:assigned_to] = @@available_resources.delete_at(0)
        end
        request
      end

      def dealloc_resource(used_res)
        used_res.each { |r| @@available_resources << r[:assigned_to] }
      end

      def build_job_cmd(job, res_req)
        opts = ""
        oml = ""
        # Dump Experiment Description in temp file
        s = Zlib::Inflate.inflate(Base64.decode64(job.oedl_script['content'].join("\n")))
        ed_file = "#{ED_PATH}/#{Digest::SHA1.hexdigest(s)}"
        f = File.open(ed_file,'w')
        f << s
        f.close
        # Set OML if required
        # TODO: Update and Uncomment the following OML setup to get the URI 
        # once the Job object is fixed.
        #unless job.oml_db.nil? || job.oml_db.empty?
        #  oml = "--oml_uri #{job.oml_db}"
        #end
        # Build experiment option line
        res_req.each do |e|
          opts = opts + "--#{e[:name]} #{e[:assigned_to]} "  
        end
        job.ec_properties.each do |e|
          opts = opts + "--#{e.value["name"]} #{e.value["value"]} " if e.value["resource"].nil?
        end
        # Put together the command line and return
        cmd = "#{EC_PATH} -e #{job.name} #{oml} #{ed_file} -- #{opts}"
      end

      # Below are commented lines from original skeleton file

      # def schedule(res_properties, job)
        # res_properties.each {|r| schedule_single(r, job)}
      # end
#
      # def schedule_single(res_property, job)
        # rd = res_property.resource_description
        # unless type = rd[:type] || rd['type']
          # raise "Missing resource type in '#{rd}'"
        # end
        # res = nil
        # case type.to_sym
        # when :node
          # require 'omf-sfa/resource/node'
          # res = OMF::SFA::Resource::Node.create(name: res_property.name)
        # else
          # raise "Unsupported resource type '#{type}'"
        # end
#
        # unless res
          # raise "Couldn't create resource '#{rd}'"
        # end
        # puts "RES>>> #{res}"
        # res.job = job
        # res.save
        # res_property.resource = res
        # res_property.save
#
      # end
    end
  end
end
