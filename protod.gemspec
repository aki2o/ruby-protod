# frozen_string_literal: true

require_relative "lib/protod/version"

Gem::Specification.new do |spec|
  spec.name = "protod"
  spec.version = Protod::VERSION
  spec.authors = ["Hiroaki Otsu"]
  spec.email = ["ootsuhiroaki@gmail.com"]

  spec.summary = "Decompiling from Ruby to proto file."
  spec.description = spec.summary
  spec.homepage = "https://github.com/aki2o/ruby-protod"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rbs", ">= 3.2.0"
  spec.add_dependency "activesupport"
  spec.add_dependency "activemodel", ">= 5.2.0"
  spec.add_dependency "google-protobuf"
end
