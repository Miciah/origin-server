require "openshift-origin-common"

module OpenShift
  module ActiveMQRoutingModule
    require 'routing_activemq_engine' if defined?(Rails) && Rails::VERSION::MAJOR == 3
  end
end

require "openshift/activemq_routing_plugin.rb"
OpenShift::RoutingService.register_provider OpenShift::ActiveMQPlugin.new
