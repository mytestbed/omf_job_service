
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/job_service/resource/user'

#require 'omf/project_authority/user_member_handler'

module OMF::JobService

  # Handles the collection of users on this AM.
  #
  class UserHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::JobService::Resource::User

      # Define handlers
      opts[:user_handler] = self
      @coll_handlers = {
        cert: lambda do |path, o| # Redirect to where the cert is stored
          raise OMF::SFA::AM::Rest::RedirectException.new("/assets/cert/#{o[:resource].name}.cer")
        end
        #user_members: (opts[:user_member_handler] || UserMemberHandler.new(opts))
      }
    end

    def create_resource(description, opts, resource_uri)
      unless bundle = description[:bundle]
        return super
      end
      OMF::JobService::Resource::User.from_bundle(bundle)
      #puts ">>>>> descr: #{description} opts: #{opts} resource_uri: #{resource_uri}"
    end
  end
end
