require 'omf/job_service/dumper'

module OMF::JobService
  class Dumper
    class Default < Dumper
      def initialize(opts = {})
        super
        @location = "#{@@dump_folder}/#{@db_name}.pg.sql.gz"
      end

      def dump
        # TODO Check if DB exists?
        `#{dump_cmd}`
        $?.exitstatus == 0 ? { success: @location } : { error: 'Database dump failed' }
      end

      private

      def dump_cmd
        "PGPASSWORD=#{@@db_conn[:password]} pg_dump -O -U #{@@db_conn[:user]} -h #{@@db_conn[:host]} -p #{@@db_conn[:port]} #{@db_name} | gzip > #{@location}"
      end
    end
  end
end
