require 'rubygems'
require 'parseconfig'
require 'openshift/routing/controllers/load_balancer'
require 'openshift/routing/models/load_balancer'

module OpenShift

  # == Simple Load Balancer Controller
  #
  # Represents a load balancer for the OpenShift Enterprise installation.
  # On initalization, the object queries the configured load balancer for
  # the configured pools and builds a table of Pool objects.
  #
  class SimpleLoadBalancerController < LoadBalancerController

    # == Pool object
    #
    # Represents the pool.  On initialization, the object queries the load balancer
    # to obtain the members of the pool named by pool_name.  These pool members are
    # stored in @members using one string of the form address:port to represent each
    # pool member.
    class Pool < LoadBalancerController::Pool
      def initialize lb_controller, lb_model, pool_name
        @lb_controller, @lb_model, @name = lb_controller, lb_model, pool_name
        @members = @lb_model.get_pool_members pool_name
        @aliases = @lb_model.get_pool_aliases pool_name
      end

      def add_member address, port
        member = address + ':' + port.to_s
        @members.push member
        @lb_model.add_pool_member @name, address, port
      end

      def delete_member address, port
        member = address + ':' + port.to_s
        @members.delete member
        @lb_model.delete_pool_member @name, address, port
      end

      def add_alias alias_str
        @aliases.push alias_str
        @lb_model.add_pool_alias @name, alias_str
      end

      def delete_alias alias_str
        @aliases.delete alias_str
        @lb_model.delete_pool_alias @name, alias_str
      end
    end

    def read_config cfgfile
      cfg = ParseConfig.new(cfgfile)

      @virtual_server_name = cfg['VIRTUAL_SERVER']
    end

    def create_pool pool_name, monitor_name=nil
      raise LBControllerException.new "Pool already exists: #{pool_name}" if pools.include? pool_name

      @lb_model.create_pools [pool_name], [monitor_name]

      pools[pool_name] = Pool.new self, @lb_model, pool_name
    end

    def delete_pool pool_name
      raise LBControllerException.new "Pool not found: #{pool_name}" unless pools.include? pool_name

      @lb_model.delete_pools [pool_name]

      pools.delete pool_name
    end

    def create_route pool_name, route_name, route_path
      raise LBControllerException.new "Route already exists: #{route_name}" if routes.include? route_name

      @lb_model.create_route pool_name, route_name, route_path
      @lb_model.attach_route route_name, @virtual_server_name if @virtual_server_name

      routes.push route_name
      active_routes.push route_name
    end

    def delete_route pool_name, route_name
      raise LBControllerException.new "Route not found: #{route_name}" unless routes.include? route_name

      @lb_model.detach_route route_name, @virtual_server_name if @virtual_server_name
      @lb_model.delete_route pool_name, route_name

      routes.delete route_name
      active_routes.delete route_name
    end

    def create_monitor monitor_name, path, up_code, type, interval, timeout
      raise LBControllerException.new "Monitor already exists: #{monitor_name}" if monitors.include? monitor_name

      @lb_model.create_monitor monitor_name, path, up_code, type, interval, timeout

      monitors.push monitor_name
    end

    def delete_monitor monitor_name, pool_name=nil
      raise LBControllerException.new "Monitor not found: #{monitor_name}" unless monitors.include? monitor_name

      @lb_model.delete_monitor monitor_name

      monitors.delete monitor_name
    end

    def pools
      @pools ||= begin
        @logger.info "Requesting list of pools from load balancer..."
        Hash[@lb_model.get_pool_names.map {|pool_name| [pool_name, Pool.new(self, @lb_model, pool_name)]}]
      end
    end

    def routes
      @routes ||= begin
        @logger.info "Requesting list of routing rules from load balancer..."
        @lb_model.get_route_names
      end
    end

    def active_routes
      @active_routes ||= begin
        @logger.info "Requesting list of active routing rules from load balancer..."
        @lb_model.get_active_route_names
      end
    end

    def monitors
      @monitors ||= begin
        @logger.info "Requesting list of monitors from load balancer..."
        @lb_model.get_monitor_names
      end
    end

    def initialize lb_model_class, logger, cfgfile
      @logger = logger

      @logger.info 'Initializing controller...'

      read_config cfgfile

      @lb_model = lb_model_class.new @logger, cfgfile
      @lb_model.authenticate
    end
  end

end
