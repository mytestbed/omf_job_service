require 'omf_base/lobject'
require 'em-synchrony'
require 'em-pg-sequel'
require 'rserve'
require 'erb'

module OMF::JobService
  class VerificationEngine < OMF::Base::LObject
    attr_reader :result

    def self.verify(name, &block)
      @@rules ||= {}
      @@rules[name] = block
    end

    verify "OML database created" do
      !@conn.nil?
    end

    verify "Completed without errors " do
      @conn[:omf_ec_meta_data].where(key: "state", value: "finished").count > 0 &&
        @conn[:omf_ec_log].where{ level > 2 }.count == 0
    end

    verify "Received messages" do
      @conn[:omf_ec_log].where(data: /^Received.+via.+/).count > 0
    end

    def initialize(opts = {})
      @local_rules = {}
      @job = opts[:job]
      @oml_db = opts[:oml_db]

      @job.r_scripts && @job.r_scripts.each do |k, v|
        verify_local k do
          eval_r_script(v)
        end
      end

      @result = {}
      @conn = Sequel.connect(@oml_db, pool_class: EM::PG::ConnectionPool, max_connections: 2)
      @@rules.merge(@local_rules).each do |k, v|
        @result[k] = instance_eval(&v)
        break unless @result[k]
      end
      @conn.disconnect
      @result
    end

    def eval_r_script(r_content)
      begin
        @r_conn = Rserve::Connection.new
        validate_def = Zlib::Inflate.inflate(Base64.decode64(r_content)).gsub(/\r/, '')
        if @oml_db =~ /^postgres:\/\/(.*):(.*)@(.+):(.*)\/(.*)$/
          user, password, host, port, db = $1, $2, $3, $4, $5
        end
        r = ERB.new(r_template).result(binding)
        result = @r_conn.eval(r).as_string
        @r_conn.close
      rescue
        resutl = 0
      end
      result
    end

    def verify_local(name, &block)
      @local_rules[name] = block
    end

    def r_template
      <<-R
experiment_id <- "<%= db %>"
oml_server <- "<%= host %>"
oml_user <- "<%= user %>"
oml_pw <- "<%= password %>"

library('RPostgreSQL')
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host=oml_server, dbname=experiment_id, user=oml_user, password=oml_pw)

<%= validate_def %>
res <- validate(con)
dbDisconnect(con)
res
      R
    end
  end
end
