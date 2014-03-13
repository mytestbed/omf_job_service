
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf/job_service/resource'
require 'thin/async'

module OMF::JobService

  # Handles the collection of measurement points for a job.
  #
  class MeasurementPointHandler < OMF::SFA::AM::Rest::RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::JobService::Resource::MeasurementPoint

      # Define handlers
      opts[:measurement_point_handler] = self

      @coll_handlers = {
        data: lambda do |path, o|
          o[:show_data] = true
          self
        end
      }

    end

    # SUPPORTING FUNCTIONS

    def show_resource_status(resource, opts)
      if resource && opts[:show_data]
        res = {
          name: resource.name,
          job: {uri: resource.job.href, status: resource.job.status}
        }

        # TODO: This is a bit of a hack. AsyncResponse ignores all the headers
        # which are added, such as CORS directives. So we need to add them here
        # as well.
        headers = {
          "Access-Control-Allow-Origin" => "*",
          "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
          "Content-Type" => 'application/javascript'
        }
        response = Thin::AsyncResponse.new(opts[:req].env, 200, headers)
        resource.data_async do |action, msg|
          case action
          when :success
            res[:schema] = msg[:schema]
            res[:data] = msg[:rows]
          when :error
            res[:error] = msg
          end

          response << res.to_json
          response.done # close the connection
        end
        return ['application/json', response]
      end
      super
    end

    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      if job = opts[:context]
        mps = job.measurement_points
      else
        mps = OMF::JobService::Resource::MeasurementPoint.all()
      end
      show_resources(mps, :measurement_points, opts)
    end

    def find_resource(resource_uri, description = {}, opts = {})
      if UUID.validate(resource_uri)
        return super
      end

      mp_a = OMF::JobService::Resource::MeasurementPoint.prop_all({o_name: resource_uri, job: opts[:context]})
      mp_a[0]
    end

  end # class


end # module
