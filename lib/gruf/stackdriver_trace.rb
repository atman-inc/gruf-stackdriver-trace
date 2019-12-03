require 'grpc'
require 'gruf'
require "google/cloud/env"
require "google/cloud/trace"
require "google/cloud/trace/async_reporter"
require "stackdriver/core/trace_context"
require_relative "stackdriver_trace/client_interceptor"
require_relative "stackdriver_trace/server_interceptor"
require_relative "stackdriver_trace/version"

module Gruf
  module StackdriverTrace
    AGENT_NAME = "gruf-stackdriver-trace #{Gruf::StackdriverTrace::VERSION}".freeze
    HEADER_KEY = 'x-trace-context'.freeze

    def self.configure
      yield config
    end

    def self.config
      @config ||= {
          service: nil,
          sampled: true,
          capture_stack: nil,
          sampler: nil,
          span_id_generator: nil
      }
    end

    def self.service
      @service ||= begin
        init_default_config

        return config[:service] if config[:service]
        return nil unless configuration.project_id

        tracer = Google::Cloud::Trace.new(
            project_id: configuration.project_id,
            credentials: configuration.credentials
        )
        Google::Cloud::Trace::AsyncReporter.new(tracer.service)
      end
    end

    def self.init_default_config
      configuration.project_id ||= Google::Cloud::Trace.default_project_id
      configuration.credentials ||= Google::Cloud.configure.credentials
      configuration.capture_stack = config.fetch(:capture_stack, false)
      configuration.sampler = config.fetch(:sampler, nil)
      configuration.span_id_generator = config.fetch(:span_id_generator, nil)
    end

    def self.configuration
      Google::Cloud::Trace.configure
    end
  end
end
