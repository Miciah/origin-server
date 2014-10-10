require 'rubygems'
require 'logger'
require 'parseconfig'
require 'stomp'
require 'timeout'
require 'yaml'

module OpenShift

  # == Load Balancer Configuration Daemon
  #
  # Represents a daemon that listens for routing updates on ActiveMQ and
  # configures a remote routing in accordance with those updates.
  # The remote load balancer is represented by an
  # OpenShift::LoadBalancerModel object and controlled using an
  # OpenShift::LoadBalancerController object.
  #
  class LoadBalancerConfigurationDaemon
    def read_config cfgfile
      cfg = ParseConfig.new(cfgfile)

      @user = cfg['ACTIVEMQ_USER'] || 'routinginfo'
      @password = cfg['ACTIVEMQ_PASSWORD'] || 'routinginfopasswd'
      @host = cfg['ACTIVEMQ_HOST'] || 'activemq.example.com'
      @port = (cfg['ACTIVEMQ_PORT'] || 61613).to_i
      @destination = cfg['ACTIVEMQ_DESTINATION'] || cfg['ACTIVEMQ_TOPIC'] || '/topic/routinginfo'
      @pool_name_format = cfg['POOL_NAME'] || 'pool_ose_%a_%n_80'
      @route_name_format = cfg['ROUTE_NAME'] || 'route_ose_%a_%n'
      @monitor_name_format = cfg['MONITOR_NAME']
      @monitor_path_format = cfg['MONITOR_PATH']
      @monitor_up_code = cfg['MONITOR_UP_CODE'] || '1'
      @monitor_type = cfg['MONITOR_TYPE'] || 'http-ecv'
      @monitor_interval = cfg['MONITOR_INTERVAL'] || '10'
      @monitor_timeout = cfg['MONITOR_TIMEOUT'] || '5'

      @update_interval = (cfg['UPDATE_INTERVAL'] || 5).to_i

      @logfile = cfg['LOGFILE'] || '/var/log/openshift/routing-daemon.log'
      @loglevel = cfg['LOGLEVEL'] || 'debug'

      # @lb_model and instances thereof should not be used except to
      # pass an instance of @lb_model_class to an instance of
      # @lb_controller_class.
      case cfg['LOAD_BALANCER'].downcase
      when 'nginx'
        require 'openshift/routing/controllers/simple'
        require 'openshift/routing/models/nginx'

        @lb_model_class = OpenShift::NginxLoadBalancerModel
        @lb_controller_class = OpenShift::SimpleLoadBalancerController
      when 'f5'
        require 'openshift/routing/controllers/simple'
        require 'openshift/routing/models/f5-icontrol-rest'

        @lb_model_class = OpenShift::F5IControlRestLoadBalancerModel
        @lb_controller_class = OpenShift::SimpleLoadBalancerController
      when 'f5_batched'
        require 'openshift/routing/controllers/batched'
        require 'openshift/routing/models/f5-icontrol-rest'

        @lb_model_class = OpenShift::F5IControlRestLoadBalancerModel
        @lb_controller_class = OpenShift::BatchedLoadBalancerController
      when 'lbaas'
        require 'openshift/routing/models/lbaas'
        require 'openshift/routing/controllers/asynchronous'

        @lb_model_class = OpenShift::LBaaSLoadBalancerModel
        @lb_controller_class = OpenShift::AsyncLoadBalancerController
      when 'dummy'
        require 'openshift/routing/models/dummy'
        require 'openshift/routing/controllers/simple'

        @lb_model_class = OpenShift::DummyLoadBalancerModel
        @lb_controller_class = OpenShift::SimpleLoadBalancerController
      when 'dummy_async'
        require 'openshift/routing/models/dummy'
        require 'openshift/routing/controllers/asynchronous'

        @lb_model_class = OpenShift::DummyLoadBalancerModel
        @lb_controller_class = OpenShift::AsyncLoadBalancerController
      else
        raise StandardError.new 'No routing configured.'
      end
    end

    def initialize cfgfile='/etc/openshift/routing.conf'
      read_config cfgfile

      @logger = Logger.new @logfile
      @logger.level = case @loglevel
                      when 'debug'
                        Logger::DEBUG
                      when 'info'
                        Logger::INFO
                      when 'warn'
                        Logger::WARN
                      when 'error'
                        Logger::ERROR
                      when 'fatal'
                        Logger::FATAL
                      else
                        raise StandardError.new "Invalid LOGLEVEL value: #{@loglevel}"
                      end

      @logger.info "Initializing routing controller..."
      @lb_controller = @lb_controller_class.new @lb_model_class, @logger, cfgfile
      #@logger.info "Found #{@lb_controller.pools.length} pools:\n" +
      #             @lb_controller.pools.map{|k,v|"  #{k} (#{v.members.length} members)"}.join("\n")

      client_id = Socket.gethostname + '-' + $$.to_s
      client_hdrs = {
        # We need STOMP 1.1 to be able to nack, and STOMP 1.1 needs the
        # client-id and host headers.
        "accept-version" => "1.1",
        "client-id" => client_id,
        "client_id" => client_id,
        "clientID" => client_id,
        "host" => @host
      }

      client_hash = {
        :hosts => [{
          :login => @user,
          :passcode => @password,
          :host => @host,
          :port => @port
        }],
        :connect_headers => client_hdrs
      }

      @logger.info "Connecting to ActiveMQ..."
      @aq = Stomp::Connection.new client_hash

      @uuid = @aq.uuid()

      subscription_hash = {
        'id' => @uuid,
        'ack' => 'client-individual',
      }

      @logger.info "Subscribing to #{@destination}..."
      @aq.subscribe @destination, subscription_hash

      @last_update = Time.now
    end

    def listen
      @logger.info "Listening..."
      while true
        begin
          msg = nil
          Timeout::timeout(@update_interval) { msg = @aq.receive }
          next unless msg

          msgid = msg.headers['message-id']
          unless msgid
            @logger.warn ["Got message without message-id from ActiveMQ:",
                          '#v+', msg, '#v-'].join "\n"
            next
          end

          @logger.debug ["Received message #{msgid}:", '#v+', msg.body, '#v-'].join "\n"

          begin
            handle YAML.load(msg.body)
          rescue Psych::SyntaxError => e
            @logger.warn "Got exception while parsing message from ActiveMQ: #{e.message}"
            # Acknowledge it to get it out of the queue.
            @aq.ack msgid, {'subscription' => @uuid}
          rescue LBControllerException, LBModelException
            @logger.info 'Got exception while handling message; sending NACK to ActiveMQ.'
            @aq.nack msgid, {'subscription' => @uuid}
          else
            @aq.ack msgid, {'subscription' => @uuid}
          end
        rescue Timeout::Error
        ensure
          update if Time.now - @last_update >= @update_interval
        end
      end
    end

    def handle event
      begin
        case event[:action]
        when :create_application
          create_application event[:app_name], event[:namespace]
        when :delete_application
          delete_application event[:app_name], event[:namespace]
        when :add_public_endpoint
          add_endpoint event[:app_name], event[:namespace], event[:public_address], event[:public_port]
        when :remove_public_endpoint
          remove_endpoint event[:app_name], event[:namespace], event[:public_address], event[:public_port]
        when :add_alias
          add_alias event[:app_name], event[:namespace], event[:alias]
        when :remove_alias
          remove_alias event[:app_name], event[:namespace], event[:alias]
        end
      rescue => e
        @logger.warn "Got an exception: #{e.message}"
        @logger.debug "Backtrace:\n#{e.backtrace.join "\n"}"
      end
    end

    def update
      @last_update = Time.now
      begin
        @lb_controller.update
      rescue => e
        @logger.warn "Got an exception: #{e.message}"
        @logger.debug "Backtrace:\n#{e.backtrace.join "\n"}"
      end
    end

    def generate_pool_name app_name, namespace
      @pool_name_format.gsub(/%./, '%a' => app_name, '%n' => namespace)
    end

    def generate_route_name app_name, namespace
      @route_name_format.gsub(/%./, '%a' => app_name, '%n' => namespace)
    end

    def generate_monitor_name app_name, namespace
      return nil unless @monitor_name_format

      @monitor_name_format.gsub(/%./, '%a' => app_name, '%n' => namespace)
    end

    def generate_monitor_path app_name, namespace
      return nil unless @monitor_path_format

      @monitor_path_format.gsub(/%./, '%a' => app_name, '%n' => namespace)
    end

    def create_application app_name, namespace
      pool_name = generate_pool_name app_name, namespace

      if @monitor_name_format && @monitor_name_format.match(/%a/) && @monitor_name_format.match(/%n/)
        monitor_name = generate_monitor_name app_name, namespace
        monitor_path = generate_monitor_path app_name, namespace
        unless monitor_name.nil? or monitor_name.empty? or monitor_path.nil? or monitor_path.empty?
          @logger.info "Creating new monitor #{monitor_name} with path #{monitor_path}"
          @lb_controller.create_monitor monitor_name, monitor_path, @monitor_up_code, @monitor_type, @monitor_interval, @monitor_timeout
        end
      end

      @logger.info "Creating new pool: #{pool_name}"
      @lb_controller.create_pool pool_name, monitor_name

      route_name = generate_route_name app_name, namespace
      route = '/' + app_name
      @logger.info "Creating new routing rule #{route_name} for route #{route} to pool #{pool_name}"
      @lb_controller.create_route pool_name, route_name, route
    end

    def delete_application app_name, namespace
      pool_name = generate_pool_name app_name, namespace

      begin
        route_name = generate_route_name app_name, namespace
        @logger.info "Deleting routing rule: #{route_name}"
        @lb_controller.delete_route pool_name, route_name
      ensure
        @logger.info "Deleting pool: #{pool_name}"
        @lb_controller.delete_pool pool_name

        # Check that the monitor is specific to the application (as indicated by
        # having the application's name and namespace in the monitor's name).
        if @monitor_name_format && @monitor_name_format.match(/%a/) && @monitor_name_format.match(/%n/)
          monitor_name = generate_monitor_name app_name, namespace
          unless monitor_name.nil? or monitor_name.empty? or monitor_path.nil? or monitor_path.empty?
            @logger.info "Deleting unused monitor: #{monitor_name}"
            # We pass pool_name to delete_monitor because some backends need the
            # name of the pool so that they will block the delete_monitor
            # operation until any corresponding delete_pool operation completes.
            @lb_controller.delete_monitor monitor_name, pool_name
          end
        end
      end
    end

    def add_endpoint app_name, namespace, gear_host, gear_port
      pool_name = generate_pool_name app_name, namespace
      @logger.info "Adding new member #{gear_host}:#{gear_port} to pool #{pool_name}"
      @lb_controller.pools[pool_name].add_member gear_host, gear_port.to_i
    end

    def remove_endpoint app_name, namespace, gear_host, gear_port
      pool_name = generate_pool_name app_name, namespace
      @logger.info "Deleting member #{gear_host}:#{gear_port} from pool #{pool_name}"
      @lb_controller.pools[pool_name].delete_member gear_host, gear_port.to_i
    end

    def add_alias app_name, namespace, alias_str
      pool_name = generate_pool_name app_name, namespace
      @logger.info "Adding new alias #{alias_str} to pool #{pool_name}"
      @lb_controller.pools[pool_name].add_alias alias_str
    end

    def remove_alias app_name, namespace, alias_str
      pool_name = generate_pool_name app_name, namespace
      @logger.info "Deleting alias #{alias_str} from pool #{pool_name}"
      @lb_controller.pools[pool_name].delete_alias alias_str
    end

  end

end
