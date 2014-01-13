
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

    def _convert_array_to_html(array, ref_name, res, opts)
      #puts "H #{ref_name}:#{ref_name.class}  >>>> #{array}::#{opts}"
      if ref_name == :ec_properties
        array.each do |p|
          puts "CCC>>> #{p.inspect}"
          if v = p.resource
            v = _convert_link_to_html(v.href)
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
