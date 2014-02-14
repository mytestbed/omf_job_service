# require 'rubygems'
# require 'json/jwt'
require 'json'

# require 'rack'
# require 'rack/showexceptions'
# require 'thin'
require 'data_mapper'
require 'omf_base/lobject'
require 'omf_base/load_yaml'

require 'omf-sfa/am/am_runner'
#require 'omf-sfa/am/am_manager'
#require 'omf-sfa/am/am_scheduler'

require 'omf/job_service'

module OMF::JobService

  class Server
    # Don't use LObject as we haveb't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Base::Loggable
    extend OMF::Base::Loggable

    ETC_DIR = File.join(File.dirname(__FILE__), '/../../../etc/omf-job-service')

    def init_logger(options)
      OMF::Base::Loggable.init_log 'server', :searchPath => File.join(File.dirname(__FILE__), 'server')
    end

    def init_data_mapper(options)
      # Configure the data store
      #
      DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
      DataMapper.setup(:default, options[:dm_db])

      require 'omf-sfa/resource'
      require 'omf/job_service/resource'
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize
      DataMapper.auto_upgrade! if options[:dm_auto_upgrade]
    end

    def init_authorization(opts)
      return # TODO: What should happen below?


      require 'json/jwt'
      require 'omf_common'
      require 'omf_common/auth'
      require 'omf_common/auth/certificate_store'
      store = OmfCommon::Auth::CertificateStore.init(opts)
      root = OmfCommon::Auth::Certificate.create_root()
      #adam = root.create_for_user('adam')
      projectA_cert = root.create_for_resource('projectA', :project)
      msg = {cnt: "shit", iss: projectA_cert}
      p = JSON::JWT.new(msg).sign(projectA_cert.key , :RS256).to_s
      puts p
    end

    def load_test_state(options)

      require  'dm-migrations'
      DataMapper.auto_migrate!

      u1_uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'adam')
      u1 = OMF::JobService::Resource::User.create(name: 'adam',
                                        uuid: u1_uuid,
                                        email: 'adam@acme.com'
                                        )
      u2_uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'bob')
      u2 = OMF::JobService::Resource::User.create(name: 'bob',
                                        uuid: u2_uuid,
                                        email: 'bob@acme.com',
                                        )

      j1_uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'job1')
      j1 = OMF::JobService::Resource::Job.create(name: 'job1', uuid: j1_uuid, user: u1)
      j2_uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'job2')
      j2 = OMF::JobService::Resource::Job.create(name: 'job2', uuid: j2_uuid, user: u1)

      # test property query
      OMF::JobService::Resource::Job.prop_all(status: 'pending')
    end

    def read_config_file(o)
      unless cf = o.delete(:config_file)
        puts "ERROR: Missing config file"
        exit(-1)
      end
      unless File.readable? cf
        puts "ERROR: Can't read config file '#{cf}'"
        exit(-1)
      end
      # This is a bit a hack as the #load method is a bit too smart for this
      f = File.basename(cf)
      d = File.dirname(cf)
      config = OMF::Base::YAML.load(f, :path => [d])[:job_service]

      defaults = o.delete(:defaults) || {}
      opts = defaults.merge(o)
      opts = config.merge(opts)
      opts
    end


    def run(opts = DEF_OPTS, argv = ARGV)
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda {
        },
        :pre_parse => lambda do |p, options|
          p.on("--test-load-state", "Load an initial state for testing") do |n| options[:load_test_state] = true end
          p.separator ""
          p.separator "Job Service options:"
          p.on("--config FILE", "Job Service config file [#{options[:config_file]}]") do |n| options[:config_file] = n end
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:defaults][:dm_db]}]") do |u| options[:dm_db] = u end
          p.on("--dm-log FILE", "Datamapper log file [#{options[:defaults][:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          p.separator ""
        end,
        :pre_run => lambda do |o|
          o = read_config_file(o)
          init_logger(o)
          init_data_mapper(o)
          init_authorization(o)
          OMF::JobService.init(o)

          require 'omf-sfa/am/am-rest/rest_handler'
          OMF::SFA::AM::Rest::RestHandler.set_service_name("OMF Job Service")
          load_test_state(o) if o[:load_test_state]
        end
      }

      opts[:rackup] ||= File.dirname(__FILE__) + '/config.ru'

      #Thin::Logging.debug = true
      require 'omf_base/thin/runner'
      OMF::Base::Thin::Runner.new(argv, opts).run!
    end
  end # class
end # module




