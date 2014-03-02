require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'

module OMF::JobService::Resource

  # This class represents a slice in the system.
  #
  class Slice < OMF::SFA::Resource::OResource

    oproperty :expiration, DataMapper::Property::Time
    oproperty :creation, DataMapper::Property::Time
    oproperty :jobs, :job, functional: false, inverse: :slice
    oproperty :aggregates, String, functional: false # XMLRP URLs

    #
    #     aggregates: [
    #       'https://fiu-hn.exogeni.net:11443/orca/xmlrpc'
    #     ]
    #
    def self.init(cfg)
      @@aggregates = cfg[:aggregates] || []
    end

    def initialize(opts)
      super
    end

    def to_hash_long(h, objs = {}, opts = {})
      super
      #h[:certificate] = href() + '/cert'
      h
    end

  end # classs
end # module
