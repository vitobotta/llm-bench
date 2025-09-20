# frozen_string_literal: true

require "yaml"

module LLMBench
  class ConfigurationManager
    attr_reader :config

    def initialize(config_path: nil)
      @config_path = config_path || File.join(__dir__, "..", "..", "models.yaml")
      @config = load_config_from_file
    end

    def load_config_from_file
      raise "Configuration file not found at #{config_path}" unless File.exist?(config_path)

      YAML.load_file(config_path)
    end

    def validate_provider_and_model!(provider_name:, model_nickname:)
      provider_config = find_provider(provider_name:)
      model_config = find_model(provider_config:, model_nickname:)

      validate_api_format!(model_config:)

      [provider_config, model_config]
    end

    private

    attr_reader :config_path

    def find_provider(provider_name:)
      provider_config = config["providers"].find { |p| p["name"] == provider_name }
      raise "Provider '#{provider_name}' not found in configuration" unless provider_config

      provider_config
    end

    def find_model(provider_config:, model_nickname:)
      model_config = provider_config["models"].find { |m| m["nickname"] == model_nickname }
      raise "Model '#{model_nickname}' not found for provider '#{provider_config["name"]}'" unless model_config

      model_config
    end

    def validate_api_format!(model_config:)
      model_config["api_format"] ||= "openai"

      valid_formats = %w[openai anthropic]
      return if valid_formats.include?(model_config["api_format"])

      raise "Invalid API format '#{model_config["api_format"]}' for model '#{model_config["nickname"]}'. Must be 'openai' or 'anthropic'"
    end
  end
end
