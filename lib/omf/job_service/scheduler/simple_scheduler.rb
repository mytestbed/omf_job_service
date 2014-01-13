
require 'omf_base/lobject'

module OMF::JobService
  module Scheduler

    class SimpleScheduler < OMF::Base::LObject

      def schedule(res_properties, job)
        res_properties.each {|r| schedule_single(r, job)}
      end

      def schedule_single(res_property, job)
        rd = res_property.resource_description
        unless type = rd[:type] || rd['type']
          raise "Missing resource type in '#{rd}'"
        end
        res = nil
        case type.to_sym
        when :node
          require 'omf-sfa/resource/node'
          res = OMF::SFA::Resource::Node.create(name: res_property.name)
        else
          raise "Unsupported resource type '#{type}'"
        end

        unless res
          raise "Couldn't create resource '#{rd}'"
        end
        puts "RES>>> #{res}"
        res.job = job
        res.save
        res_property.resource = res
        res_property.save

      end
    end
  end
end
