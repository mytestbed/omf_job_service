

module OMF
  module JobService
    DEF_OPTS = {
      :app_name => 'job_service',
      :port => 8002,
      #:log => '/tmp/am_server.log',
      :dm_db => 'sqlite:///tmp/job_service_test.db',
      :dm_log => '/tmp/job_service_test-dm.log',
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
      require 'omf/job_service/scheduler/simple_scheduler'
      @@scheduler = Scheduler::SimpleScheduler.new
    end
  end
end


if __FILE__ == $0
  # Run the service
  #
  require 'omf/job_service/server'

  OMF::JobService::Server.new.run()

end
