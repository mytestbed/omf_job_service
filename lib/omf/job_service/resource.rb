

module OMF
  module JobService
    module Resource
      class User < OMF::SFA::Resource::OResource; end
    end
  end
end

require 'omf/job_service/resource/user'
require 'omf/job_service/resource/job'
require 'omf/job_service/resource/ec_property'
require 'omf/job_service/resource/measurement_point'
require 'omf/job_service/resource/verification'

OMF::SFA::Resource::OComponent.oproperty :job, OMF::JobService::Resource::Job


# require 'omf/project_authority/resource/project'
# require 'omf/project_authority/resource/project_member'
