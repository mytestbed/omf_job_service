require 'omf_base/lobject'

module OMF::JobService
  class Dumper < OMF::Base::LObject
    def self.init(opts = {})
      if opts[:db_server].nil?
        raise ArgumentError, "Missing database server connection information :db_server"
      end

      @@dump_folder = opts[:dump_folder] || "/tmp"

      if opts[:db_server] =~ /^postgres:\/\/(.*):(.*)@(.+):(.*)$/
        user, password, host = $1, $2, $3
        host, port = *host.split(':')
        port ||= 5432
        @@db_conn = { host: host, user: user, password: password, port: port }
      else
        error "Malformed database server address :db_server: '#{opts[:db_server]}'"
      end

      rekuire = opts[:require] || "omf/job_service/dumper/default"
      klass = opts[:class] || "OMF::JobService::Dumper::Default"
      require rekuire
      @@klass = klass.split("::").inject(Object) do |mod, klass_name|
        mod.const_get(klass_name)
      end
    end

    def self.dump(opts = {})
      reply = @@klass.new(opts).dump
      if reply[:success]
        [200, {'Content-Type' => 'application/json'}, JSON.pretty_generate(reply)]
      elsif reply[:error]
        [500, {'Content-Type' => 'application/json'}, JSON.pretty_generate({ error: 'Database dump failed' })]
      else
        [500, {'Content-Type' => 'application/json'}, JSON.pretty_generate({ error: "Malformed reply from dump method: '#{reply}'" })]
      end
    end

    def self.dump_folder
      @@dump_folder
    end

    def initialize(opts)
      opts = Hash[opts.map { |k, v| [k.to_sym, v] }]
      raise ArgumentError, "Missng OML database name :db_name" if opts[:db_name].nil?
      @db_name = opts[:db_name]
    end
  end
end
