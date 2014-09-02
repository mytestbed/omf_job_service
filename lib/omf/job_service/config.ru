

REQUIRE_LOGIN = false

require 'rack/file'
# TODO: Is still necessary now that we have CORS middleware?
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end
end

require 'omf-sfa/resource/oresource'
OMF::SFA::Resource::OResource.href_resolver do |res, o|
  rtype = res.resource_type.to_sym
  unless [:job, :user].include?(rtype)
    rtype = :resource
  end
  "http://#{Thread.current[:http_host]}/#{rtype}s/#{res.uuid}"
end

opts = OMF::Base::Thin::Runner.instance.options

require 'rack/cors'
use Rack::Cors, debug: true do
  allow do
    origins '*'
    resource '*', :headers => :any, :methods => [:get, :post, :options]
  end
end

require 'omf-sfa/am/am-rest/session_authenticator'
use OMF::SFA::AM::Rest::SessionAuthenticator, #:expire_after => 10,
          :login_url => (REQUIRE_LOGIN ? '/login' : nil),
          :no_session => ['^/$', '^/login', '^/logout', '^/readme', '^/assets']


map '/users' do
  require 'omf/job_service/user_handler'
  run opts[:user_handler] || OMF::JobService::UserHandler.new(opts)
end

map '/jobs' do
  require 'omf/job_service/job_handler'
  run opts[:job_handler] || OMF::JobService::JobHandler.new(opts)
end

map '/queue' do
  require 'omf/job_service/queue_handler'
  run OMF::JobService::QueueHandler.new(opts)
end


map '/resources' do
  require 'omf/job_service/resource_handler'
  run opts[:resource_handler] || OMF::JobService::ResourceHandler.new(opts)
end

require 'omf/job_service/resource/job'
log_dir = OMF::JobService::Resource::Job.log_file_dir
map '/logs' do
  if log_dir
    run MyFile.new(log_dir)
  else
    run do |env|
      [401 ,{'Content-Type' => 'text'}, "Log files are not configured for this instance"]
    end
  end
end

require 'omf/job_service/dumper'
map '/dump' do
  handler = proc do |env|
    req = Rack::Request.new(env)
    if req.get?
      MyFile.new(OMF::JobService::Dumper.dump_folder).call(env)
    elsif req.post?
      opts = JSON.parse(req.body.read)
      opts[:http_host] = env["HTTP_HOST"]
      OMF::JobService::Dumper.dump(opts)
    end
  end
  run handler
end

if REQUIRE_LOGIN
  map '/login' do
    require 'omf-sfa/am/am-rest/login_handler'
    run OMF::SFA::AM::Rest::LoginHandler.new(opts[:am][:manager], opts)
  end
end

map "/readme" do
  require 'bluecloth'
  p = lambda do |env|
    s = File::read(File.dirname(__FILE__) + '/../../../README.md')
    frag = BlueCloth.new(s).to_html
    page = {
      service: '<h2><a href="/?_format=html">ROOT</a>/<a href="/readme">Readme</a></h2>',
      content: frag.gsub('http://localhost:8002', "http://#{env["HTTP_HOST"]}")
    }
    [200 ,{'Content-Type' => 'text/html'}, OMF::SFA::AM::Rest::RestHandler.render_html(page)]
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../share/assets')
end

map "/" do
  handler = Proc.new do |env|
    req = ::Rack::Request.new(env)
    case req.path_info
    when '/'
      http_prefix = "http://#{env["HTTP_HOST"]}"
      toc = ['README', :queue, :jobs, :users].map do |s|
        "<li><a href='#{http_prefix}/#{s.to_s.downcase}?_format=html&_level=0'>#{s}</a></li>"
      end
      page = {
        service: 'Job Service',
        content: "<ul>#{toc.join("\n")}</ul>"
      }
      [200 ,{'Content-Type' => 'text/html'}, OMF::SFA::AM::Rest::RestHandler.render_html(page)]
    when '/favicon.ico'
      [301, {'Location' => '/assets/image/favicon.ico', "Content-Type" => ""}, ['Next window!']]
    else
      OMF::Base::Loggable.logger('rack').warn "Can't handle request '#{req.path_info}'"
      [401, {"Content-Type" => ""}, "Sorry!"]
    end
  end
  run handler
end

