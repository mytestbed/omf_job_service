module OMF::JobService::Resource
  class Verification < OMF::SFA::Resource::OResource
    oproperty :o_name, String # TODO: Hack alert
    oproperty :oml_db, String

    oproperty :job, :job

    def initialize(opts)
      super
      self.o_name = opts[:name]
    end

    def href
      self.job.href + '/verifications/' + self.uuid
    end

    def to_hash_long(h, objs = {}, opts = {})
      super
      h[:data] = href + '/data'
      h
    end
  end
end
