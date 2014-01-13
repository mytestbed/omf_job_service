
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/resource/oresource'

require 'omf/job_service/resource'
#require 'omf/project_authority/user_member_handler'

module OMF::JobService

  # Handles the collection of resources attached or available to jobs.
  #
  class ResourceHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SFA::Resource::OResource

      # Define handlers
      opts[:resource_handler] = self
      @coll_handlers = {
        # cert: lambda do |path, o| # Redirect to where the cert is stored
          # raise OMF::SFA::AM::Rest::RedirectException.new("/assets/cert/#{o[:resource].name}.cer")
        # end
        #user_members: (opts[:user_member_handler] || UserMemberHandler.new(opts))
      }
    end

  end
end
