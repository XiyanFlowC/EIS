# frozen_string_literal: true

require_relative "lib/eis/version"

Gem::Specification.new do |spec|
  spec.name = "eis"
  spec.version = EIS::VERSION
  spec.authors = %w[XiyanFlowC jitingcn]
  spec.email = %w[junyifan20@gamil.com jiting@jtcat.com]

  spec.summary = "ELF's binary exporting and importing helper lib."
  spec.homepage = "https://github.com/XiyanFlowC/EIS"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/XiyanFlowC/EIS"
  # spec.metadata["changelog_uri"] = ""

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "elftools", "~> 1"
  spec.add_dependency "activesupport"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "standard", "~> 1"
end
