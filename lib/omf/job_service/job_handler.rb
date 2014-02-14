
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/job_service/resource'

module OMF::JobService

  # Handles the collection of users on this AM.
  #
  class JobHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::JobService::Resource::Job

      # Define handlers
      opts[:job_handler] = self
      @coll_handlers = {
        #user_members: (opts[:user_member_handler] || UserMemberHandler.new(opts))
      }
    end

    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      q = {}
      opts[:req].params.each do |k, v|
        case k
        when 'pending'
          q[:status] = 'pending'
        when 'active'
          q[:status] = 'active'
        else
          warn "Unknown selector '#{k}' for Job list"
        end
      end
      debug "Job list selectors '#{q}'"
      resources = OMF::JobService::Resource::Job.prop_all(q)

      #resources = @resource_class.all()
      show_resources(resources, nil, opts)
    end

    # Inform the scheduler about a new incoming job
    #
    def on_new_resource(resource)
      debug "Created: #{resource}"
      OMF::JobService.scheduler.on_new_job(resource)
    end

    def _convert_obj_to_html(obj, ref_name, res, opts)
      # puts "O #{ref_name}:#{ref_name.class}  >>>> #{obj.class}: #{obj}"
      if ref_name == :oedl_script
        res << " <span class='value'>...</span> "
        return
      end
      super
    end

    def _convert_array_to_html(array, ref_name, res, opts)
      # puts "H #{ref_name}:#{ref_name.class}  >>>> #{array}::#{opts}"
      if ref_name == :ec_properties
        array.each do |p|
          #puts "CCC>>> #{p}"
          if p.resource?
            if r = p.resource
              v = _convert_link_to_html(v.href)
            else
              v = "Unassigned resource - #{p.resource_description}"
            end
          else
            v = p.value
          end
          res << "<li><span class='key'>#{p.name}:</span> #{v} </li>"
        end
      else
        super
      end
    end

  end
end
