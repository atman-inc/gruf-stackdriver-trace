module Gruf
  module StackdriverTrace
    class ClientInterceptor < Gruf::Interceptors::ClientInterceptor
      def call(request_context:)
        Google::Cloud::Trace.in_span("grpc-request") do |span|
          return yield request_context unless span
          set_request_metadata(request_context.metadata, span)
          add_request_labels(span.labels, request_context)
          result = Gruf::Interceptors::Timer.time do
            yield request_context
          end
          add_response_labels(span.labels, result)
          result.message
        end
      rescue => e
        p e
      end

      private

      def set_request_metadata(metadata, span)
        metadata[Gruf::StackdriverTrace::HEADER_KEY] = span.trace.trace_context.to_s
      end

      def add_request_labels(labels, request_context)
        set_label(labels, Google::Cloud::Trace::LabelKey::RPC_REQUEST_TYPE, request_context.type.to_s)
      end

      def add_response_labels(labels, result)
        code = result.successful? ? ::GRPC::Core::StatusCodes::OK : result.message.code
        set_label(labels, Google::Cloud::Trace::LabelKey::RPC_STATUS_CODE, code.to_s)
      end

      def set_label labels, key, value
        labels[key] = value if value.is_a? ::String
      end
    end
  end
end
