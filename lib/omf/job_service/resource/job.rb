require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'

module OMF::JobService::Resource

  # This class represents a job in the system.
  #
  class Job < OMF::SFA::Resource::OResource

    oproperty :creation, DataMapper::Property::Time
    oproperty :description, String
    oproperty :priority, Integer
    oproperty :oidl_script, String
    oproperty :ec_properties, Object, functional: false, set_filter: :filter_ec_property


    oproperty :status, String
    oproperty :user, :user, inverse: :jobs

    def initialize(opts)
      super
      self.creation = Time.now
      self.status = :pending

      resources = self.ec_properties.select do |p|
        puts "PPP>> #{p.inspect}"
        p.resource? && p.resource.nil?
      end.compact
      unless resources.empty?
        OMF::JobService.scheduler.schedule(resources, self)
      end
    end

    def filter_ec_property(val)
      unless val.is_a? EcProperty
        val = EcProperty.new(val)
        val.job = self

        begin
          val.save
        rescue Exception => ex
          puts "EXXX>>> #{ex}"
          raise ex
        end
      end
      val
    end

    def to_hash_brief(opts = {})
      h = super
      h[:status] = self.status
      h
    end


  end # classs
end # module
