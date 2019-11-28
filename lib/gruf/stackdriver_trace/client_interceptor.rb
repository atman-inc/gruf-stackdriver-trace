module Gruf
  module StackdriverTrace
    class ClientInterceptor
      def call(request_context:)
        Google::Cloud::Trace.in_span("grpc-request") do |span|
          return yield unless span
          add_request_labels(span.labels, request_context)
          response = yield
          add_response_labels(span.labels, response)
          response
        end
      end

      private

      def add_request_labels(labels, request_context)
        set_label(labels, Google::Cloud::Trace::LabelKey::RPC_REQUEST_TYPE, request_context.type)
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_URL, request_context.method)
      end

      def add_response_labels(labels, response)
        set_label(labels, Google::Cloud::Trace::LabelKey::HTTP_STATUS_CODE, response.code.to_s)
      end

      def set_label labels, key, value
        labels[key] = value if value.is_a? ::String
      end
    end
  end
end
