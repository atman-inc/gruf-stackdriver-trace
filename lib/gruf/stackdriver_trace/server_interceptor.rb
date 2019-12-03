require_relative 'label'

module Gruf
  module StackdriverTrace
    class ServerInterceptor < Gruf::Interceptors::ServerInterceptor
      include Gruf::StackdriverTrace::Label

      def call
        return yield if service.nil?

        trace = create_trace(request)
        begin
          Google::Cloud::Trace.set(trace)
          Google::Cloud::Trace.in_span("grpc-request-received") do |span|
            configure_span(span, request)
            yield
          end
        ensure
          Google::Cloud::Trace.set(nil)
          send_trace(trace)
        end
      rescue => e
        p e
      end

      private

      def create_trace(request)
        trace_context = get_trace_context(request)
        Google::Cloud::Trace::TraceRecord.new(
          service.project,
          trace_context,
          span_id_generator: configuration.span_id_generator
        )
      end

      def get_trace_context(request)
        header = request.active_call.metadata[Gruf::StackdriverTrace::HEADER_KEY]
        return Stackdriver::Core::TraceContext.new(
            sampled: Gruf::StackdriverTrace.config[:sampled],
            capture_stack: Gruf::StackdriverTrace.config[:capture_stack]
        ) unless header
        tc = Stackdriver::Core::TraceContext.parse_string(header)
        if tc.sampled?.nil?
          sampler = configuration.sampler ||
            Google::Cloud::Trace::TimeSampler.default
          sampled = sampler.call(simulated_rack_env(request))
          tc = Stackdriver::Core::TraceContext.new(
            trace_id: tc.trace_id,
            span_id: tc.span_id,
            sampled: sampled,
            capture_stack: sampled && configuration.capture_stack
          )
        end
        tc
      end

      def configure_span(span, request)
        method_name = [
            request.service.name,
            request.method_key.to_s.camelize
        ].join('/')
        span.name = "Recv: #{method_name}"
        set_stack_trace(span, 4)
        set_basic_labels(span.labels, request, method_name)
        set_extended_labels(span.labels)
        span
      end

      def set_extended_labels(labels)
        if Google::Cloud.env.app_engine?
          set_label(
            labels,
            label_key::GAE_APP_MODULE,
            Google::Cloud.env.app_engine_service_id
          )
          set_label(
            labels,
            label_key::GAE_APP_MODULE_VERSION,
            Google::Cloud.env.app_engine_service_version
          )
        end
        # TODO: set GKE env options
      end

      def send_trace(trace)
        if trace.trace_context.sampled?
          begin
            service.patch_traces(trace)
          rescue StandardError => e
            handle_error(e, logger: Gruf.logger)
          end
        end
      end

      def handle_error(error, logger: nil)
        if error_callback
          error_callback.call(error)
        else
          msg = "Transmit to Stackdriver Trace failed: #{error.inspect}"
          if logger
            logger.error(msg)
          else
            warn(msg)
          end
        end
      end

      def error_callback
        if @error_callback.nil?
          @error_callback = :unset
          configuration_callback = configuration.on_error
          configuration_callback ||= Google::Cloud.configure.on_error
          @error_callback = configuration_callback if configuration_callback
        end

        return nil if @error_callback == :unset
        @error_callback
      end

      def simulated_rack_env(request)
        # simulate rack env with Gruf's request
        @simulated_rack_env ||= {
          'SCRIPT_NAME' => request.service_key,
          'PATH_INFO' => request.method_key
        }
      end

      def get_path(request)
        path = "#{request.service_key}#{request.method_key}"
        path = "/#{path}" unless path.start_with? "/"
        path
      end

      def service
        @service ||= Gruf::StackdriverTrace.service
      end

      def configuration
        @configuration ||= Gruf::StackdriverTrace.configuration
      end
    end
  end
end
