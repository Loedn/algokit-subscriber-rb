# frozen_string_literal: true

require_relative "lib/algokit/subscriber/version"

Gem::Specification.new do |spec|
  spec.name = "algokit-subscriber"
  spec.version = Algokit::Subscriber::VERSION
  spec.authors = ["Loedn"]
  spec.email = ["loedn@pm.me"]

  spec.summary = "Simple, flexible Algorand transaction subscription and indexing for Ruby"
  spec.description = "A Ruby port of algokit-subscriber-ts that provides transaction subscription and " \
                     "indexing capabilities for the Algorand blockchain"
  spec.homepage = "https://github.com/loedn/algokit-subscriber-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/loedn/algokit-subscriber-rb"
  spec.metadata["changelog_uri"] = "https://github.com/loedn/algokit-subscriber-rb/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "yard", "~> 0.9"
end
