require "google/cloud/env"
require "google/cloud/trace/async_reporter"
require "stackdriver/core/trace_context"

module Gruf
  module StackdriverTrace
    class ServerInterceptor
      def initialize(service: nil, **kwargs)
        load_config(kwargs)

        if service
          @service = service
        else
          project_id = configuration.project_id

          if project_id
            credentials = configuration.credentials
            tracer = Google::Cloud::Trace.new project_id: project_id,
                                              credentials: credentials
            @service = Google::Cloud::Trace::AsyncReporter.new tracer.service
          end
        end
      end

      def call
        trace = create_trace(request)
        begin
          Google::Cloud::Trace.set(trace)
          Google::Cloud::Trace.in_span("grpc-request") do |span|
            configure_span(span, request)
            yield
          end
        ensure
          Google::Cloud::Trace.set(nil)
          send_trace(trace)
        end
      end

      private

      def create_trace(request)
        trace_context = get_trace_context(request)
        Google::Cloud::Trace::TraceRecord.new \
            @service.project,
            trace_context,
            span_id_generator: configuration.span_id_generator
      end

      def get_trace_context(request)
        header = request.active_call.metadata[Gruf::StackdriverTrace::HEADER_KEY]
        return Stackdriver::Core::TraceContext.new unless header
        tc = Stackdriver::Core::TraceContext.parse_string(header)
        if tc.sampled?.nil?
          sampler = configuration.sampler ||
            Google::Cloud::Trace::TimeSampler.default
          sampled = sampler.call(simulated_rack_env(request))
          tc = Stackdriver::Core::TraceContext.new \
                trace_id: tc.trace_id,
                span_id: tc.span_id,
                sampled: sampled,
                capture_stack: sampled && configuration.capture_stack
        end
        tc
      end

      def configure_span(span, request)
        span.name = get_path(request)
        set_basic_labels(span.labels, request)
        set_extended_labels(span.labels, span.trace.trace_context.capture_stack?)
        span
      end

      def set_basic_labels(labels, request)
        set_label(labels, Google::Cloud::Trace::LabelKey::AGENT, AGENT_NAME)
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_HOST, Socket.gethostname)
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_CLIENT_PROTOCOL, 'http2')
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_USER_AGENT, get_ua(request))
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_URL, get_path(request))
        set_label(labels, Google::Cloud::Trace::LabelKey::PID, ::Process.pid.to_s)
        set_label(labels, Google::Cloud::Trace::LabelKey::TID, ::Thread.current.object_id.to_s)
      end

      def set_extended_labels(labels, capture_stack)
        if capture_stack
          Google::Cloud::Trace::LabelKey.set_stack_trace(labels, skip_frames: 3)
        end
        if Google::Cloud.env.app_engine?
          set_label(
            labels,
            Google::Cloud::Trace::LabelKey::GAE_APP_MODULE,
            Google::Cloud.env.app_engine_service_id
          )
          set_label(
            labels,
             Google::Cloud::Trace::LabelKey::GAE_APP_MODULE_VERSION,
             Google::Cloud.env.app_engine_service_version
          )
        end
        # TODO: set GKE env options
      end

      def send_trace(trace)
        if @service && trace.trace_context.sampled?
          begin
            @service.patch_traces(trace)
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
          configuration_callback ||= Cloud.configure.on_error
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

      def get_ua(request)
        request.active_call.metadata['user-agent'] || nil
      end

      def set_label labels, key, value
        labels[key] = value if value.is_a? ::String
      end

      def load_config(**kwargs)
        capture_stack = kwargs[:capture_stack]
        configuration.capture_stack = capture_stack unless capture_stack.nil?

        sampler = kwargs[:sampler]
        configuration.sampler = sampler unless sampler.nil?

        generator = kwargs[:span_id_generator]
        configuration.span_id_generator = generator unless generator.nil?

        init_default_config
      end

      def init_default_config
        configuration.project_id ||= Trace.default_project_id
        configuration.credentials ||= Cloud.configure.credentials
        configuration.capture_stack ||= false
      end

      def configuration
        Google::Cloud::Trace.configure
      end
    end
  end
end
