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

    verify "Finished" do
      @conn[:omf_ec_meta_data].where(key: "state", value: "finished").count > 0
    end

    verify "No errors" do
      @conn[:omf_ec_log].where{ level > 1 }.count == 0
    end

    verify "Received messages" do
      @conn[:omf_ec_log].where(data: /^Received.+via.+/).count > 0
    end

    verify "Using R script" do
      if @r_script
        # TODO Use R library to verify it
      end
    end

    def initialize(opts = {})
      @r_script =  opts[:r_script]
      @result = {}
      @conn = Sequel.connect(opts[:oml_db], pool_class: EM::PG::ConnectionPool, max_connections: 2)
      @@rules.each do |k, v|
        @result[k] = instance_eval(&v)
        break unless @result[k]
      end
      @result
    end
  end
end
