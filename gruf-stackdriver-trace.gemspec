
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gruf/stackdriver_trace/version"

Gem::Specification.new do |spec|
  spec.name          = "gruf-stackdriver-trace"
  spec.version       = Gruf::StackdriverTrace::VERSION
  spec.authors       = ["Kei Takahashi"]
  spec.email         = ["dameleon@gmail.com"]

  spec.summary       = %q{Gruf🤝Stackdriver trace}
  spec.description   = %q{Plugin for Stackdirver trace for bigcommerce/gruf}
  spec.homepage      = "https://github.com/atman-inc/gruf-stackdriver-trace"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "gruf", "~> 2.7"
  spec.add_development_dependency "google-cloud-trace", "~> 0.36"
end
