
require 'omf_base/lobject'
require 'omf_base/exec_app'
require 'digest/sha1'


module OMF::JobService
  module Scheduler

    class SimpleScheduler < OMF::Base::LObject

      POLL_PERIOD = 5 # period in second when the scheduler should wake up
      SUPPORTED_RESOURCE_TYPES = [ :node ]


      def initialize(opts)
        @available_resources = opts[:resources]
        @hard_timeout = opts[:hard_timeout]
        debug "Available resource: #{@available_resources}"
        @started = false
        @running_jobs = []
      end

      def start
        return if @started
        @started = true

        EM.add_periodic_timer(POLL_PERIOD) do

          # DEBUG ONLY
          # all_jobs = OMF::JobService::Resource::Job.all()
          # all_jobs.each { |j| debug ">>> Job - '#{j.name}' - '#{j.status}'" }

          # refresh the list of pending jobs from the database
          pending_jobs = OMF::JobService::Resource::Job.prop_all(status: 'pending')
          next if pending_jobs.empty?

          # Refresh the list of available resources
          # TODO: in this simple example, for now just get a test list of known fixed resources
          # (some more code to be placed here to get the list of available resource!)
          debug "Available resource: #{@available_resources}"
          res  = @available_resources
          schedule(res, pending_jobs.first)

        end
      end

      def on_new_job(job)
        debug "Received new job '#{job}'"
        # Periodic scheduler is taking care of it
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
        if alloc_resources(resources, job)
          info "Running job '#{job.name}' with resource(s) #{job.resources.to_s}"
          # Start the job
          EM.next_tick do
            if @hard_timeout
              EM.add_timer(@hard_timeout) { job.abort_job }
            end
            job.run { dealloc_resources_for_job(job) }
          end
        end
      end

      def alloc_resources(res, job)
        failed = false
        alloc_res = job.resources.map do |e|
          next nil if failed # no point trying anymore
          res = alloc_resource(e)
          unless res
            debug "Job '#{job.name}'. Not enough free resources to run this job now, will try again later."
            failed = true
          end
          res
        end.compact
        if failed
          # TODO: Free allocate resources
          return false
        end
        job.resources.each_with_index do |e, i|
          e.resource_name = alloc_res[i]
          e.save
          job.save
        end
        return true
      end

      def alloc_resource(descr)
        type = descr.resource_type
        unless supported_types?(type)
          raise UnknownResourceException("requests a resource of type '#{type}' not supported by this scheduler")
        end
        res = @available_resources.delete_at(0)
      end

      def dealloc_resources_for_job(job)
        job.resources.each { |r| @available_resources << r.resource_name }
      end

    end
  end
end
