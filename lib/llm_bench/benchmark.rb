# frozen_string_literal: true

require "yaml"
require "json"
require "net/http"
require "uri"
require "time"

module LLMBench
  class Benchmark
    attr_reader :config, :provider, :model, :start_time, :end_time

    def initialize(provider_name:, model_nickname:, print_result: false, config: nil)
      @provider_name = provider_name
      @model_nickname = model_nickname
      @print_result = print_result
      @config = config || load_config
      validate_provider_and_model!
    end

    def load_config
      config_path = File.join(__dir__, "..", "models.yaml")
      raise "Configuration file models.yaml not found" unless File.exist?(config_path)

      YAML.load_file(config_path)
    end

    def validate_provider_and_model!
      provider_config = @config["providers"].find { |p| p["name"] == @provider_name }
      raise "Provider '#{@provider_name}' not found in configuration" unless provider_config

      model_config = provider_config["models"].find { |m| m["nickname"] == @model_nickname }
      raise "Model '#{@model_nickname}' not found for provider '#{@provider_name}'" unless model_config

      model_config["api_format"] ||= "openai"

      raise "Invalid API format '#{model_config["api_format"]}' for model '#{@model_nickname}'. Must be 'openai' or 'anthropic'" unless %w[openai anthropic].include?(model_config["api_format"])

      @provider = provider_config
      @model = model_config
    end

    def run_benchmark
      puts "=== LLM Benchmark ==="
      puts "Provider: #{@provider_name}"
      puts "Model: #{@model_nickname} (#{@model["id"]})"
      puts "Starting benchmark..."

      @start_time = Time.now
      puts "Start time: #{@start_time.strftime("%Y-%m-%d %H:%M:%S.%3N")}"

      response = make_api_call

      @end_time = Time.now
      puts "End time: #{@end_time.strftime("%Y-%m-%d %H:%M:%S.%3N")}"

      calculate_and_display_metrics(response: response)
    end

    def anthropic_format?
      @model["api_format"] == "anthropic"
    end

    def api_endpoint
      anthropic_format? ? "#{@provider["base_url"]}/v1/messages" : "#{@provider["base_url"]}/chat/completions"
    end

    def build_request_headers
      headers = { "Content-Type" => "application/json" }
      if anthropic_format?
        headers["x-api-key"] = @provider["api_key"]
        headers["anthropic-version"] = "2023-06-01"
      else
        headers["Authorization"] = "Bearer #{@provider["api_key"]}"
      end
      headers
    end

    def build_request_body
      base_body = {
        model: @model["id"],
        messages: [{ role: "user", content: @config["prompt"] }]
      }

      if anthropic_format?
        base_body.merge(max_tokens: 1000)
      else
        base_body.merge(max_tokens: 1000, temperature: 0.7)
      end
    end

    def extract_response_content(response)
      if anthropic_format?
        extract_anthropic_content(response: response)
      else
        response.dig("choices", 0, "message", "content") || ""
      end
    end

    def extract_token_counts(response:, message_content:)
      if anthropic_format?
        input_tokens = response.dig("usage", "input_tokens") || estimate_tokens(text: @config["prompt"])
        output_tokens = response.dig("usage", "output_tokens") || estimate_tokens(text: message_content)
      else
        input_tokens = response.dig("usage", "prompt_tokens") || estimate_tokens(text: @config["prompt"])
        output_tokens = response.dig("usage", "completion_tokens") || estimate_tokens(text: message_content)
      end
      [input_tokens, output_tokens]
    end

    def make_api_call
      uri = URI.parse(api_endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"

      build_request_headers.each { |key, value| request[key] = value }
      request.body = build_request_body.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      response = http.request(request)

      handle_api_error(response: response) unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def handle_api_error(response:)
      error_response = JSON.parse(response.body)
      error_msg = error_response["msg"] || error_response["message"] ||
                  error_response.dig("error", "message") || response.message
      raise "API request failed: #{response.code} - #{error_msg}"
    rescue JSON::ParserError
      raise "API request failed: #{response.code} #{response.message}"
    end

    def calculate_metrics(response:)
      duration = @end_time - @start_time
      message_content = extract_response_content(response)
      input_tokens, output_tokens = extract_token_counts(response: response, message_content: message_content)

      total_tokens = input_tokens + output_tokens
      tokens_per_second = total_tokens / duration if duration.positive?

      {
        duration: duration,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: total_tokens,
        tokens_per_second: tokens_per_second,
        message_content: message_content
      }
    end

    def calculate_and_display_metrics(response:)
      metrics = calculate_metrics(response: response)

      puts "\n=== Results ==="
      puts "Duration: #{metrics[:duration].round(3)} seconds"
      puts "Input tokens: #{metrics[:input_tokens]}"
      puts "Output tokens: #{metrics[:output_tokens]}"
      puts "Total tokens: #{metrics[:total_tokens]}"
      puts "Tokens per second: #{metrics[:tokens_per_second].round(2)}"

      puts "\n=== Message Content ==="
      puts metrics[:message_content] if @print_result
    end

    def extract_anthropic_content(response:)
      return "Error: #{response["msg"]}" if response.key?("code") && response.key?("msg") && response.key?("success")

      content_blocks = response["content"]

      if content_blocks.is_a?(Array) && !content_blocks.empty?
        text_block = content_blocks.find { |block| block.is_a?(Hash) && block["type"] == "text" }
        text_block ? text_block["text"] : nil
      elsif response.dig("content", 0, "text")
        response.dig("content", 0, "text")
      end
    end

    def estimate_tokens(text:)
      (text.length / 4.0).round
    end

    def run_benchmark_for_results
      @start_time = Time.now
      response = make_api_call
      @end_time = Time.now

      metrics = calculate_metrics(response: response)
      {
        provider: @provider_name,
        model: @model_nickname,
        total_tokens: metrics[:total_tokens],
        tokens_per_second: metrics[:tokens_per_second].round(2),
        duration: metrics[:duration].round(3),
        success: true,
        message_content: metrics[:message_content]
      }
    rescue StandardError => e
      {
        provider: @provider_name,
        model: @model_nickname,
        total_tokens: 0,
        tokens_per_second: 0,
        duration: 0,
        success: false,
        error: e.message,
        message_content: ""
      }
    end
  end
end
