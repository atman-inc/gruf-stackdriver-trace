module Gruf
  module StackdriverTrace
    class TimeSampler < Google::Cloud::Trace::TimeSampler
      DEFAULT_RPC_BLACKLIST = {
        'grpc.health.v1.Health' => [
          'Check'
        ].freeze
      }.freeze

      def initialize(qps: 0.1, path_blacklist: DEFAULT_PATH_BLACKLIST, rpc_blacklist: DEFAULT_RPC_BLACKLIST)
        super(qps: qps, path_blacklist: DEFAULT_RPC_BLACKLIST)
        @rpc_blacklist = rpc_blacklist
      end

      def call(request)
        return false if rpc_blacklisted?(request.service.service_name, request.method_key.to_s.camelize)
        super({})
      end

      def path_blacklisted?(_env)
        # Google::Cloud::Trace::TimeSampler checks blacklist with rack env
        # but this context hasn't rack env. we disable it.
        false
      end

      def rpc_blacklisted?(service, method)
        methods = @rpc_blacklist[service]
        methods && methods.include?(method)
      end
    end
  end
end
