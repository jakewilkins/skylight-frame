# frozen_string_literal: true

require_relative "lib/skylight/frame/version"

Gem::Specification.new do |spec|
  spec.name = "skylight-frame"
  spec.version = Skylight::Frame::VERSION
  spec.authors = ["Jake Wilkins"]
  spec.email = ["jakewilkins@github.com"]

  spec.summary = "Don't use this."
  spec.description = "This ain't shit."
  spec.homepage = "https://github.com/jakewilkins/skylight-frame"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = ""

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = IO.popen(%w[find . -name '*.rb' -not -path "./test/*"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "ruby-keychain", "~> 0.4.0" if RUBY_PLATFORM.include?("darwin")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
