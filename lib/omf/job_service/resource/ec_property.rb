
require 'omf_base/lobject'
require 'base64'

module OMF::JobService
  module Resource

    class EcProperty < OMF::Base::LObject
      include DataMapper::Resource

      property :id,   Serial
      property :name, String
      property :_value, String, length: 256
      property :_resource_description, String, length: 512

      belongs_to :job, OMF::JobService::Resource::Job
      belongs_to :resource, OMF::SFA::Resource::OResource, :required => false


      def initialize(opts)
        puts "EC>>> #{opts}"
        v = opts.delete(:value) || opts.delete('value')
        rd = opts.delete(:resource) || opts.delete('resource')
        super
        if v
          self._value = Base64.encode64(Marshal.dump(v))
        end
        if rd
          self._resource_description = Base64.encode64(Marshal.dump(rd))
        end
      end

      def value
        unless @value
          if v = self._value
            @value = Marshal.load(Base64.decode64(v))
          end
        end
        @value
      end

      def resource_description
        unless @resource_description
          if rd = self._resource_description
            @resource_description = Marshal.load(Base64.decode64(rd))
          end
        end
        @resource_description
      end

      def resource?
        self.resource_description != nil
      end

      # Serialisation
      def to_json(*args)
        {
          JSON.create_id => self.class.name,
          'id' => self.id
        }.to_json(*args)
      end

      def to_s
        "<#{self.class}: name=#{self.name} value=#{self.value} rd=#{self.resource_description}>"
      end

      def self.json_create(state)
        self.first(id: state['id'])
      end

    end
  end
end
