require_relative 'label'

module Gruf
  module StackdriverTrace
    class ClientInterceptor < Gruf::Interceptors::ClientInterceptor
      include Gruf::StackdriverTrace::Label

      def call(request_context:)
        Google::Cloud::Trace.in_span("grpc-request") do |span|
          return yield request_context unless span
          set_request_metadata(request_context.metadata, span)
          configure_span(span, request_context)
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

      def configure_span(span, request_context)
        span.name = "Sent.#{request_context.method_name}"
        set_stack_trace(span, 4)
        set_basic_labels(span.labels, request_context)
        set_label(span.labels, label_key::RPC_REQUEST_TYPE, request_context.type.to_s)
        span
      end

      def add_response_labels(labels, result)
        code = result.successful? ? ::GRPC::Core::StatusCodes::OK : result.message.code
        set_label(labels, label_key::RPC_STATUS_CODE, code.to_s)
      end
    end
  end
end
