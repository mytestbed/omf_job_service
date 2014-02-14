
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
          all_jobs = OMF::JobService::Resource::Job.all()
          all_jobs.each { |j| debug ">>> Job - '#{j.name}' - '#{j.status}'" }
          debug ">>> available resource: #{@@available_resources}"

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
        # Try to allocate resources to this job
        # If it has all its requested resources fully allocated then run it
puts ">>> TDB - schedule -  #{job.resource.to_s}"
job.resource.each { |e| puts ">>> TDB - schedule - resource - #{e.name} - #{e.resource_type} - value: '#{e.resource_name}'" }

        if alloc_resource(resources, job)
          info "Running job '#{job.name}' with resource(s) #{job.resource.to_s}"

job.resource.each { |e| puts ">>> TDB - schedule - resource - #{e.name} - #{e.resource_type} - value: '#{e.resource_name}'" }

          # Start the job
          job.run { |j| dealloc_resource(j) }
        end
      end

      def alloc_resource(res, job)
        job.ec_properties.each do |e|
          if e.resource?
            type = e.resource_type
            unless type.nil?
              if supported_types?(type.downcase.to_sym)
puts ">>> TDB - alloc_resource A - #{e.name} - value: '#{e.resource_name}' (free: #{@@available_resources})"
                e.resource_name = @@available_resources.delete_at(0) 
                e.save
                job.save
puts ">>> TDB - alloc_resource B - #{e.name} - value: '#{e.resource_name}' (free: #{@@available_resources})"
                if e.resource_name.nil?
                  warn "Job '#{job.name}'. Not enough free resources to run this job now, will try again later."
                  return false
                end
              else
                warn "Job '#{job.name}' requests a resource of type '#{type}' not supported by this scheduler. Cannot schedule this job!"
                job.status = :unsupported
                return false
              end
            end
          end
        end
        return true
      end

      def dealloc_resource(job)
        job.resource.each { |r| @@available_resources << r.resource_name }
      end

#      def build_job_cmd(job, res_req)
#        opts = ""
#        oml = ""
#        # Dump Experiment Description in temp file
#        s = Zlib::Inflate.inflate(Base64.decode64(job.oedl_script['content'].join("\n")))
#        ed_file = "#{ED_PATH}/#{Digest::SHA1.hexdigest(s)}"
#        f = File.open(ed_file,'w')
#        f << s
#        f.close
#        # Set OML if required
#        # TODO: Update and Uncomment the following OML setup to get the URI 
#        # once the Job object is fixed.
#        #unless job.oml_db.nil? || job.oml_db.empty?
#        #  oml = "--oml_uri #{job.oml_db}"
#        #end
#        # Build experiment option line
#        res_req.each do |e|
#          opts = opts + "--#{e[:name]} #{e[:assigned_to]} "  
#        end
#        job.ec_properties.each do |e|
#          opts = opts + "--#{e.name} #{e.value} " unless e.resource?
#        end
#        # Put together the command line and return
#        cmd = "#{EC_PATH} -e #{job.name} #{oml} #{ed_file} -- #{opts}"
#      end

    end
  end
end
