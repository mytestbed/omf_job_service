require 'omf/job_service/verification_engine'

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

    def run_verification
      EM.synchrony do
        yield OMF::JobService::VerificationEngine.new(oml_db: self.oml_db, job: self.job).result
      end
    end
  end
end
