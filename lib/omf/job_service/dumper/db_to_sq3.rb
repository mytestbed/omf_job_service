require 'omf/job_service/dumper'

module OMF::JobService
  class Dumper
    # Simple example of a script to dump an entire experiment database from a
    # PostreSQL server into dump file suitable for importing into SQLite3
    #
    # This could be used to customise the 'Download/Dump Data' button of the
    # 'Execute' panel of Labwiki.
    #
    # This requires pg_dump command line app to be available on the path
    class DBToSQ3 < Dumper
      def initialize(opts = {})
        super
        @http_location = "http://#{opts[:http_host]}/dump/#{@db_name}.sq3"
        @location = "#{@@dump_folder}/#{@db_name}.sq3"
      end

      def dump
        # PSQL password: either use a pgpass file or set the PGPASSWORD env variable
        # Get rid of all PostgreSQL specific commands inside the dump
        out=`#{dump_cmd}`
        result = []
        lines = File.readlines(@location)
        lines.each do | line |
          next if line =~ /SELECT pg_catalog.setval/  # sequence value's
          next if line =~ /SET /                      # postgres specific config
          next if line =~ /--/                        # comment
          next if line =~ /ALTER/                        # comment
          next if line =~ /CREATE EXTENSION/                        # comment
          next if line =~ /CREATE ON EXTENSION/                        # comment
          next if line =~ /COMMENT ON EXTENSION/                        # comment
          next if line =~ /CREATE SEQUENCE/                        # comment
          next if line =~ /START WITH/                        # comment
          next if line =~ /INCREMENT/                        # comment
          next if line =~ /NO MINVALUE/                        # comment
          next if line =~ /NO MAXVALUE/                        # comment
          next if line =~ /CACHE/                        # comment
          next if line =~ /ADD CONSTRAINT/                        # comment
          next if line =~ /REVOKE ALL/                        # comment
          next if line =~ /GRANT ALL/

          # replace true and false for 't' and 'f'
          line.gsub!("true","'t'")
        line.gsub!("false","'f'")
        result << line
        end

        # Write the resulting file suitable for SQLite3 import.
        File.open(file, "w") do |f|
          # Add BEGIN and END so we add it to 1 transaction. Increase speed!
          f.puts("BEGIN;")
          result.each{|line| f.puts(line) unless line=="\n"}
          f.puts("END;")
        end
        { success: @http_location }
      end

      private

      def dump_cmd
        "/usr/bin/pg_dump -h #{@@db_conn[:host]} --inserts -U #{@@db_conn[:user]} #{@db_name} -f #{@location}"
      end
    end
  end
end
