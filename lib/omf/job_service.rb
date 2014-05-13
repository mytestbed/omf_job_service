
module OMF
  module JobService
    DEF_OPTS = {
      :app_name => 'job_service',
      :port => 8002,
      :config_file => File.absolute_path(File.join(File.dirname(__FILE__), '../../etc/omf_job_service.yaml')),
      #:log => '/tmp/am_server.log',
      :defaults => {
        :dm_log => '/tmp/job_service_test-dm.log',
        :dm_db => 'sqlite:///tmp/job_service_test.db'
      },
      :rackup => File.dirname(__FILE__) + '/job_service/config.ru',
    }

    DEF_SSL_OPTS = {
      :ssl => {
        :cert_file => File.expand_path("~/.gcf/am-cert.pem"),
        :key_file => File.expand_path("~/.gcf/am-key.pem"),
        #:verify_peer => true,
        :verify_peer => false
      }
    }

    @@scheduler = nil

    def self.scheduler()
      @@scheduler
    end

    def self.init(opts)

      if jcfg = opts.delete(:jobs)
        require 'omf/job_service/resource/job'
        Resource::Job.init(jcfg)
      end

      # Setup scheduler
      scfg = opts.delete(:scheduler) || {}
      klass = scfg.delete(:class)
      requ = scfg.delete(:require)

      require requ
      s_class = klass.split("::").inject(Object) do |mod, klass_name|
        mod.const_get(klass_name)
      end

      @@scheduler = s_class.new(scfg)
      EM.next_tick { @@scheduler.start }
    end
  end
end
