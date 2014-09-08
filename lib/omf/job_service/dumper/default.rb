require 'omf/job_service/dumper'

module OMF::JobService
  class Dumper
    class Default < Dumper
      def initialize(opts = {})
        super
        @http_host = "http://#{opts[:http_host]}"
        @location = "#{@@dump_folder}/#{@db_name}.pg.sql.gz"
        @path = "dump/#{@db_name}.pg.sql.gz"
      end

      def dump
        `#{dump_cmd}`
        full_path = "#{@http_host}/#{@path}"
        $?.exitstatus == 0 ? { success: full_path } : { error: 'Database dump failed' }
      end

      private

      def dump_cmd
        "PGPASSWORD=#{@@db_conn[:password]} pg_dump -O -U #{@@db_conn[:user]} -h #{@@db_conn[:host]} -p #{@@db_conn[:port]} #{@db_name} | gzip > #{@location}"
      end
    end
  end
end
