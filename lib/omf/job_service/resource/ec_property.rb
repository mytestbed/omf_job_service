
require 'omf_base/lobject'
require 'base64'

module OMF::JobService
  module Resource

    class EcProperty < OMF::Base::LObject
      include DataMapper::Resource

      property :id,   Serial
      property :name, String
      property :_is_resource, Boolean
      property :_marshal, String, length: 512

      belongs_to :job, OMF::JobService::Resource::Job
      belongs_to :resource, OMF::SFA::Resource::OResource, :required => false


      def initialize(opts)
        #puts "EC>>> #{opts}"
        v = opts.delete(:value) || opts.delete('value')
        rd = opts.delete(:resource) || opts.delete('resource')
        super
        if v && rd
          raise "Can't have both :value and :resource defined. Pick one"
        end
        self._marshal = Base64.encode64(Marshal.dump(v || rd))
        self._is_resource = (rd != nil)
      end

      def value
        unless @value
          if self._is_resource
            raise "This is not a 'value' property"
          end
          @value = Marshal.load(Base64.decode64(self._marshal))
        end
        @value
      end

      def value=(v)
        if self._is_resource
          raise "This is not a 'value' property"
        end
        self._marshal = Base64.encode64(Marshal.dump(v))
        @value = v
      end

      def resource_description
        unless @resource_description
          unless self._is_resource
            raise "This is not a 'resource' property"
          end
          @resource_description = Marshal.load(Base64.decode64(self._marshal))
        end
        @resource_description || {}
      end

      def resource_description=(rd)
        unless self._is_resource
          raise "This is not a 'resource' property"
        end
        self._marshal = Base64.encode64(Marshal.dump(rd))
        @resource_description = rd
      end

      def resource_name
        rd = resource_description
        rd.nil? ? nil : rd[:name] || rd['name']
      end

      def resource_name=(name)
        rd = resource_description
        rd.delete('name')
        rd[:name] = name
        resource_description = rd
      end

      def resource_type
        rd = resource_description
        rd.nil? ? nil : rd[:type] || rd['type']
      end

      def resource_type=(type)
        rd = resource_description
        rd.delete('type')
        rd[:type] = type
        resource_description = rd
      end

      def resource?
        self._is_resource
      end

      def to_hash()
        h = {name: self.name}
        if rd = self.resource_description
          h[:resource] = rd
        else
          h[:value] = self.value
        end
        h
      end
      # Serialisation
      def to_json(*args)
        to_hash().to_json(*args)
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
