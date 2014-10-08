require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'
require 'em-synchrony'
require 'em-pg-sequel'

module OMF::JobService::Resource

  # This class represents a measurement point associated with a Job
  #
  class MeasurementPoint < OMF::SFA::Resource::OResource
    DEF_QUERY_LIMIT = 1000


    oproperty :o_name, String # TODO: Hack alert
    oproperty :caption, String
    oproperty :sql, String
    oproperty :oml_db, String
    oproperty :job, :job

    def initialize(opts)
      super
      self.o_name = opts[:name]
    end

    def href
      self.job.href + '/measurement_points/' + self.uuid
    end

    def to_hash_long(h, objs = {}, opts = {})
      super
      h[:data] = href + '/data'
      h
    end

    def data_async(interval = 5, &callback)
      dr = DatabaseReader.new(self)
      dr.query_async(self.sql, &callback)
    end

  end # class

  class DatabaseReader < OMF::SFA::Resource::OResource

    CLASS2TYPE = {
      Fixnum => 'int32',
      Float => 'double',
      String => 'string'
    }

    def initialize(mp)
      @mp = mp
    end

    def query_async(query, interval = 5, &callback)
      @query = query
      @done = false
      EM.next_tick do
        fetch_data(&callback)
        unless @done
          timer = EM.add_periodic_timer(interval) do
            if @done
              timer.cancel
            else
              fetch_data(&callback)
            end
          end
        end
      end
    end

    def fetch_data(&callback)
      #db_uri = "postgres://#{@config_opts[:user]}:#{@config_opts[:pwd]}@#{@config_opts[:host]}/#{exp_id}"
      info "Attempting to connect to OML backend (DB) on '#{@mp.oml_db}'"
      Fiber.new do
        begin
          connection = Sequel.connect(@mp.oml_db, pool_class: EM::PG::ConnectionPool, max_connections: 2)
          q = connection.fetch(@query)
          rows = q.map(q.columns)
          schema = discover_schema(q, rows)
          callback.call(:success, {rows: rows, schema: schema})
          @done = true
        rescue => e
          if e.message =~ /PG::Error: FATAL:  database .+ does not exist/
            debug "Database '#{@mp.oml_db}' doesn't exist yet"
          elsif m = e.message.match(/ERROR:  relation "(.*)" does not exist/)
            debug "Table '#{m[1]}' doesn't exist yet"
          else
            error "Connection to OML backend (DB) failed - #{e}"
            debug e.backtrace.join("\n\t")
            callback.call(:error, "Connection to OML backend (DB) failed - #{e}")
            @done = true
          end
        ensure
          connection.disconnect if connection
        end
      end.resume
    end

    def discover_schema(q, rows)
      return [] if rows.empty?

      columns = q.columns
      schema = []
      rows[0].each_with_index do |v, i|
        unless type = CLASS2TYPE[v.class]
          warn "Unknown type mapping for class '#{v.class}'"
          type = :string
        end
        schema << [columns[i], type]
      end
      schema
    end


  end
end # module
