require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/job_service/resource'
require 'thin/async'

module OMF::JobService
  class VerificationHandler < OMF::SFA::AM::Rest::RestHandler
    def initialize(opts = {})
      super
      @resource_class = OMF::JobService::Resource::Verification

      opts[:verification_handler] = self
    end

    def show_resource_status(resource, opts)
      res = {
        name: resource.name,
        job: {uri: resource.job.href, status: resource.job.status}
      }

      headers = {
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Content-Type" => 'application/javascript'
      }
      response = Thin::AsyncResponse.new(opts[:req].env, 200, headers)
      resource.run_verification do |result|
        res[:result] = result
        response << res.to_json
        response.done # close the connection
      end
      return ['application/json', response]
      super
    end

    def show_resource_list(opts)
      if job = opts[:context]
        verifications = job.verifications
      else
        verifications = OMF::JobService::Resource::Verification.all()
      end
      show_resources(verifications, :verification, opts)
    end

    def find_resource(resource_uri, description = {}, opts = {})
      if UUID.validate(resource_uri)
        return super
      end
      verifications = OMF::JobService::Resource::Verification.prop_all({o_name: resource_uri, job: opts[:context]})
      verifications[0]
    end
  end
end
