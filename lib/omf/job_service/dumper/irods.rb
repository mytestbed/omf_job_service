require 'omf/job_service/dumper'

module OMF::JobService
  class Dumper
    class IRODS < Dumper
      def initialize
        super
      end

      def dump
        raise NotImplementedError
      end
    end
  end
end
