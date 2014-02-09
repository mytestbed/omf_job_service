require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'

module OMF::JobService::Resource

  # This class represents a job in the system.
  #
  class Job < OMF::SFA::Resource::OResource

    oproperty :creation, DataMapper::Property::Time
    oproperty :description, String
    oproperty :priority, Integer
    oproperty :slice, String
    oproperty :oedl_script, String
    oproperty :ec_properties, Object, functional: false, set_filter: :filter_ec_property
    oproperty :oml_db, String


    oproperty :status, String
    oproperty :user, :user, inverse: :jobs

    def initialize(opts)
      super
      self.creation = Time.now
      self.status = :pending
      # TODO: Make this configurable
      self.oml_db = 'postgres://oml2:omlisgoodforyou@srv.mytestbed.net/' + self.name
    end

    def filter_ec_property(val)
      unless val.is_a? EcProperty
        val = EcProperty.new(val)
        val.job = self

        begin
          val.save
        rescue Exception => ex
          puts "ERROR: Can't save - #{ex.resource.errors.inspect} - #{ex.resource.errors.full_messages}"
          raise ex
        end
      end
      val
    end

    def to_hash_brief(opts = {})
      h = super
      h[:status] = self.status
      h[:oml_db] = self.oml_db
      h
    end


  end # classs
end # module
