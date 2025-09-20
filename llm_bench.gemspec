# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'llm_bench/version'

Gem::Specification.new do |spec|
  spec.name          = "llm_bench"
  spec.version       = LLMBench::VERSION
  spec.authors       = ["Vito"]
  spec.email         = []

  spec.summary       = "A tool for benchmarking LLM performance across different providers and models"
  spec.description   = <<~DESC
    LLM Bench is a Ruby gem that allows you to benchmark and compare the performance
    of different Large Language Model providers and APIs. It supports both OpenAI and
    Anthropic-compatible API formats, provides parallel execution, and includes
    continuous tracking capabilities with CSV export.
  DESC
  spec.homepage      = "https://github.com/vitobotta/llm-bench"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = ["llm_bench"]
  spec.require_paths = ["lib"]

  # Color support for enhanced output
  spec.add_dependency "colorize", "~> 1.1"
end
