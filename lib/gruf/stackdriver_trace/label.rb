module Gruf
  module StackdriverTrace
    module Label
      def label_key
        Google::Cloud::Trace::LabelKey
      end

      def set_label(labels, key, value)
        labels[key] = value.to_s
      end

      def set_basic_labels(labels, request, method_name)
        set_label(labels, label_key::AGENT, Gruf::StackdriverTrace::AGENT_NAME)
        set_label(labels, label_key::HTTP_HOST, get_host(request))
        set_label(labels, label_key::HTTP_CLIENT_PROTOCOL, 'http2')
        set_label(labels, label_key::HTTP_USER_AGENT, get_ua(request))
        set_label(labels, label_key::HTTP_URL, method_name)
        set_label(labels, label_key::PID, ::Process.pid)
        set_label(labels, label_key::TID, ::Thread.current.object_id)
      end

      def set_stack_trace(span, skip_frames)
        tc = span.trace.trace_context
        return unless tc.capture_stack?
        label_key.set_stack_trace(span.labels, skip_frames: skip_frames)
      end

      def get_ua(request)
        metadata = request_context?(request) ? request.metadata : request.active_call.metadata
        metadata['user-agent'] || nil
      end

      def get_host(request)
        call = request_context?(request) ? request.call : request.active_call
        call.peer
      end

      def request_context?(request)
        request.is_a?(Gruf::Outbound::RequestContext)
      end
    end
  end
end
