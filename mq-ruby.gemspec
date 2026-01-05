# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "mq-ruby"
  spec.version = "0.1.1"
  spec.authors = ["Takahiro Sato"]

  spec.summary = "Ruby bindings for mq Markdown processing"
  spec.description = "mq is a jq-like command-line tool for Markdown processing. This gem provides Ruby bindings for mq."
  spec.homepage = "https://mqlang.org/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/harehare/mq-ruby"
  spec.extensions = ["extconf.rb"]

  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*.{rs,toml,rb}",
    "src/**/*.rs",
    "Cargo.toml",
    "Cargo.lock",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
  ]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "rb_sys", "~> 0.9"
end
