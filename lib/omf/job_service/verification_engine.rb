require 'omf_base/lobject'
require 'em-synchrony'
require 'em-pg-sequel'

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
        @conn[:omf_ec_log].where{ level > 1 }.count == 0
    end

    verify "Received messages" do
      @conn[:omf_ec_log].where(data: /^Received.+via.+/).count > 0
    end

    def initialize(opts = {})
      @local_rules = {}
      @job = opts[:job]

      @job.r_scripts.each do |k, v|
        verify_local k do
          eval_r_script(v)
        end
      end

      @result = {}
      @conn = Sequel.connect(opts[:oml_db], pool_class: EM::PG::ConnectionPool, max_connections: 2)
      @@rules.merge(@local_rules).each do |k, v|
        @result[k] = instance_eval(&v)
        break unless @result[k]
      end
      @result
    end

    def eval_r_script(r_content)
      puts Zlib::Inflate.inflate(Base64.decode64(r_content))
      rand(100)
    end

    def verify_local(name, &block)
      @local_rules[name] = block
    end
  end
end
