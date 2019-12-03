# Gruf::StackdriverTrace

Add Stackdriver trace support for [gruf](https://github.com/bigcommerce/gruf).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gruf-stackdriver-trace'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gruf-stackdriver-trace

## Usage

### ServerInterceptor

Configure and use interceptor in gruf's initializer.

```
require 'gruf/stackdriver_trace'

Gruf.configure do |c|
  # optional
  Gruf::StackdriverTrace.configure do |config|
  end
  
  c.interceptors.use(Gruf::StackdriverTrace::ServerInterceptor)
end
```

### ClientInterceptor

Specify `Gruf::StackdriverTrace::ClientInterceptor` instance to `client_options[:interceptors]`.

```
client = Gruf::Client.new(
    service: Rpc::Products,
    client_options: {
        interceptors: [
            Gruf::StackdriverTrace::ClientInterceptor.new
        ]
    }
)
resp = client.call(:GetProduct)
```

NOTE: `Gruf::StackdriverTrace::ClientInterceptor` will not be enabled if the tracing context of `Gruf::StackdriverTrace::ServerInterceptor` or Stackdriver Trace(ex. use with Rails middleware) cannot be obtained.


### Configuration

You can configure with `Gruf::StackdriverTrace.configure { |config| ... }`.

REF: https://github.com/googleapis/google-cloud-ruby/blob/master/stackdriver/INSTRUMENTATION_CONFIGURATION.md#trace

- `config[:service]` (default: `nil`)
    - A reporter Class that provides to send traced data 
    - SEE: https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-trace/lib/google/cloud/trace/async_reporter.rb
- `config[:sampled]` (default: `true`)
    - Whether to capture tracing 
    - `true`: enable tracing
    - `false`: disable tracing
    - ex. `config[:sampled] = Rails.env.production?` to be enable tracing in only production env.
- `config[:capture_stack]` (default: `true`)
    - Whether to capture stack traces for each span
    - `true`: enable to recording of stack trace
    - `false`: disable to recording of stack trace
- `config[:sampler]` (default: `nil`)
    - A sampler Class makes the decision whether to record a trace for each request
    - SEE: https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-trace/lib/google/cloud/trace/time_sampler.rb
- `config[:span_id_generator]` (default: `nil`)
    - A generator Proc that generates the name String for new TraceRecord
    - SEE: https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-trace/lib/google/cloud/trace/trace_record.rb#L59-L60

#### Without GCP environment

If you are running the application locally, in self-hosted VMs, or a third party hosting service, you will need to provide the project ID and credentials (keyfile) to the Google Cloud client library. See [this section](https://github.com/googleapis/google-cloud-ruby/tree/master/google-cloud-trace#running-locally-and-elsewhere) for details.

ex.

```
Google::Cloud.configure do |config|
  config.project_id = "your-project-id"
  config.keyfile = "path/to/service-account.json"
end
```

## Development

TODO

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atman-inc/gruf-stackdriver-trace. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Gruf::StackdriverTrace project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/gruf-stackdriver-trace/blob/master/CODE_OF_CONDUCT.md).
