require "gruf/stackdriver_trace/version"

module Gruf
  module StackdriverTrace
    AGENT_NAME = "gruf-stackdriver-trace #{Gruf::StackdriverTrace::VERSION}".freeze
    HEADER_KEY = 'x-trace-context'.freeze
  end
end
