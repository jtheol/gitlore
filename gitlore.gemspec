# frozen_string_literal: true

require_relative "lib/gitlore/version"

Gem::Specification.new do |spec|
  spec.name = "gitlore"
  spec.version = Gitlore::VERSION
  spec.authors = ["jtheol"]
  spec.email = ["jtheol"]
  spec.summary = "A simple cli tool to create summaries of git commits using LLMs."
  spec.description = "A simple cli tool to create summaries of git commits using LLMs."
  spec.homepage = "https://github.com/jtheol/gitlore"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables << "gitlore"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
