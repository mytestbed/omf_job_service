
require 'omf_base/lobject'
require 'omf/job_service/resource'
require 'omf-sfa/am/am-rest/rest_handler'

module OMF::JobService

  # Handles the collection of users on this AM.
  #
  class QueueHandler < OMF::Base::LObject

    def initialize(opts = {})
      @opts = opts
    end

    def on_get(req)
      {
        active: OMF::JobService::Resource::Job.prop_all(status: 'active'),
        pending: OMF::JobService::Resource::Job.prop_all(status: 'pending')
      }
    end

    ########################

    def convert_to_html(body, env)
      req = ::Rack::Request.new(env)
      path = req.path.split('/').select { |p| !p.empty? }
      h2 = ["<a href='/?_format=html&_level=0'>ROOT</a>"]
      path.each_with_index do |s, i|
        h2 << "<a href='/#{path[0 .. i].join('/')}?_format=html&_level=#{i % 2 ? 0 : 1}'>#{s}</a>"
      end

      content = ["<h3>Active</h3>"]
      content += _convert_list(body[:active])

      content += ["<h3>Pending</h3>"]
      content += _convert_list(body[:pending])

      OMF::SFA::AM::Rest::RestHandler::render_html(
        service: h2.join('/'),
        content: content.join("\n")
      )
    end

    def _convert_list(jobs)
      if jobs.empty?
        return ['<span class="empty">empty</span>']
      end

      content = ["<ul>"]
      jobs.each do |job|
        #puts "JOB #{job.uuid} -- #{job.status}"
        content << "<li>#{_convert_job_to_link job}</li>"
      end
      content << '</ul>'
      content
    end

    def _convert_job_to_link(job)
      "<a href='/jobs/#{job.uuid}?_format=html&_level=2'>#{job.name}</a>"
    end


    def dispatch(req)
      method = req.request_method
      case method
      when 'GET'
        ['application/json', on_get(req)]
      else
        raise OMF::SFA::AM::Rest::IllegalMethodException.new method
      end
    end

    def call(env)
      begin
        Thread.current[:http_host] = env["HTTP_HOST"]
        req = ::Rack::Request.new(env)
        content_type, body = dispatch(req)
        if req['_format'] == 'html'
          body = convert_to_html(body, env)
          content_type = 'text/html'
        elsif content_type == 'application/json'
          body = JSON.pretty_generate(body)
        end
        return [200 ,{'Content-Type' => content_type}, body + "\n"]
      rescue OMF::SFA::AM::Rest::RackException => rex
        return rex.reply
      rescue OMF::SFA::AM::Rest::RedirectException => rex
        debug "Redirecting to #{rex.path}"
        return [301, {'Location' => rex.path, "Content-Type" => ""}, ['Next window!']]
      rescue Exception => ex
        body = {
          :error => {
            :reason => ex.to_s,
            :bt => ex.backtrace #.select {|l| !l.start_with?('/') }
          }
        }
        warn "ERROR: #{ex}"
        debug ex.backtrace.join("\n")
        return [500, {"Content-Type" => 'application/json'}, body]
      end
    end

  end
end
