#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'net/http'
require 'uri'
require 'time'
require 'optparse'

class LLMBenchmark
  attr_reader :config, :provider, :model, :start_time, :end_time

  def initialize(provider_name, model_nickname, print_result = false)
    @provider_name = provider_name
    @model_nickname = model_nickname
    @print_result = print_result
    @config = load_config
    validate_provider_and_model!
  end

  def load_config
    config_path = File.join(__dir__, 'models.yaml')
    unless File.exist?(config_path)
      raise "Configuration file models.yaml not found"
    end

    YAML.load_file(config_path)
  end

  def validate_provider_and_model!
    provider_config = @config['providers'].find { |p| p['name'] == @provider_name }
    unless provider_config
      raise "Provider '#{@provider_name}' not found in configuration"
    end

    model_config = provider_config['models'].find { |m| m['nickname'] == @model_nickname }
    unless model_config
      raise "Model '#{@model_nickname}' not found for provider '#{@provider_name}'"
    end

    # Set default API format if not specified
    model_config['api_format'] ||= 'openai'

    # Validate API format
    unless ['openai', 'anthropic'].include?(model_config['api_format'])
      raise "Invalid API format '#{model_config['api_format']}' for model '#{@model_nickname}'. Must be 'openai' or 'anthropic'"
    end

    @provider = provider_config
    @model = model_config
  end

  def run_benchmark
    puts "=== LLM Benchmark ==="
    puts "Provider: #{@provider_name}"
    puts "Model: #{@model_nickname} (#{@model['id']})"
    puts "Starting benchmark..."

    @start_time = Time.now
    puts "Start time: #{@start_time.strftime('%Y-%m-%d %H:%M:%S.%3N')}"

    response = make_api_call

    @end_time = Time.now
    puts "End time: #{@end_time.strftime('%Y-%m-%d %H:%M:%S.%3N')}"

    calculate_and_display_metrics(response)
  end

  def make_api_call
    # Use different endpoints based on API format
    if @model['api_format'] == 'anthropic'
      uri = URI.parse("#{@provider['base_url']}/v1/messages")
    else
      uri = URI.parse("#{@provider['base_url']}/chat/completions")
    end

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    # Set authentication headers based on API format
    if @model['api_format'] == 'anthropic'
      request['x-api-key'] = @provider['api_key']
      request['anthropic-version'] = '2023-06-01'
    else
      request['Authorization'] = "Bearer #{@provider['api_key']}"
    end

    # Build request body based on API format
    if @model['api_format'] == 'anthropic'
      request.body = {
        model: @model['id'],
        max_tokens: 1000,
        messages: [
          { role: 'user', content: @config['prompt'] }
        ]
      }.to_json
    else
      request.body = {
        model: @model['id'],
        messages: [
          { role: 'user', content: @config['prompt'] }
        ],
        max_tokens: 1000,
        temperature: 0.7
      }.to_json
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      # Try to parse error response for better debugging
      begin
        error_response = JSON.parse(response.body)
        error_msg = error_response.dig('msg') || error_response.dig('message') || error_response.dig('error', 'message') || response.message
        raise "API request failed: #{response.code} - #{error_msg}"
      rescue JSON::ParserError
        raise "API request failed: #{response.code} #{response.message}"
      end
    end

    JSON.parse(response.body)
  end

  def calculate_and_display_metrics(response)
    duration = @end_time - @start_time

    # Extract tokens based on API format
    if @model['api_format'] == 'anthropic'
      input_tokens = response.dig('usage', 'input_tokens') || estimate_tokens(@config['prompt'])
      output_tokens = response.dig('usage', 'output_tokens') || estimate_tokens(extract_anthropic_content(response) || '')
      message_content = extract_anthropic_content(response) || ''
    else
      input_tokens = response.dig('usage', 'prompt_tokens') || estimate_tokens(@config['prompt'])
      output_tokens = response.dig('usage', 'completion_tokens') || estimate_tokens(response.dig('choices', 0, 'message', 'content') || '')
      message_content = response.dig('choices', 0, 'message', 'content') || ''
    end

    total_tokens = input_tokens + output_tokens
    tokens_per_second = total_tokens / duration if duration > 0

    puts "\n=== Results ==="
    puts "Duration: #{duration.round(3)} seconds"
    puts "Input tokens: #{input_tokens}"
    puts "Output tokens: #{output_tokens}"
    puts "Total tokens: #{total_tokens}"
    puts "Tokens per second: #{tokens_per_second.round(2)}"

    if @print_result
      puts "\n=== Message Content ==="
      puts message_content
    end
  end

  def extract_anthropic_content(response)
    # Check if this is an error response
    if response.key?('code') && response.key?('msg') && response.key?('success')
      return "Error: #{response['msg']}"
    end

    # Anthropic API response format: content is an array of content blocks
    # Each block has a 'type' and 'text' field
    content_blocks = response.dig('content')

    # Handle different response formats
    if content_blocks.is_a?(Array) && !content_blocks.empty?
      # Standard format: content is an array of blocks
      text_block = content_blocks.find { |block| block.is_a?(Hash) && block['type'] == 'text' }
      text_block ? text_block['text'] : nil
    elsif response.dig('content', 0, 'text')
      # Fallback for different response structure
      response.dig('content', 0, 'text')
    else
      nil
    end
  end

  def estimate_tokens(text)
    # Rough estimation: ~4 characters per token
    (text.length / 4.0).round
  end

  def run_benchmark_for_results
    @start_time = Time.now
    response = make_api_call
    @end_time = Time.now

    duration = @end_time - @start_time

    # Extract tokens and content based on API format
    if @model['api_format'] == 'anthropic'
      input_tokens = response.dig('usage', 'input_tokens') || estimate_tokens(@config['prompt'])
      output_tokens = response.dig('usage', 'output_tokens') || estimate_tokens(extract_anthropic_content(response) || '')
      message_content = extract_anthropic_content(response) || ''
    else
      input_tokens = response.dig('usage', 'prompt_tokens') || estimate_tokens(@config['prompt'])
      output_tokens = response.dig('usage', 'completion_tokens') || estimate_tokens(response.dig('choices', 0, 'message', 'content') || '')
      message_content = response.dig('choices', 0, 'message', 'content') || ''
    end

    total_tokens = input_tokens + output_tokens
    tokens_per_second = total_tokens / duration if duration > 0

    result = {
      provider: @provider_name,
      model: @model_nickname,
      total_tokens: total_tokens,
      tokens_per_second: tokens_per_second.round(2),
      duration: duration.round(3),
      success: true,
      message_content: message_content
    }
  rescue => e
    {
      provider: @provider_name,
      model: @model_nickname,
      total_tokens: 0,
      tokens_per_second: 0,
      duration: 0,
      success: false,
      error: e.message,
      message_content: ''
    }
  end
end

class ParallelBenchmark
  def initialize(config, print_result = false)
    @config = config
    @print_result = print_result
  end

  def run_all
    puts "=== LLM Benchmark ==="
    puts "Running benchmarks on all configured models..."
    puts "Starting at #{Time.now.strftime('%Y-%m-%d %H:%M:%S.%3N')}"
    puts

    benchmarks = create_benchmarks
    results = run_parallel(benchmarks)

    display_results_table(results)
    display_summary(results)
  end

  def run_silent
    benchmarks = create_benchmarks
    run_parallel(benchmarks)
  end

  private

  def create_benchmarks
    benchmarks = []

    @config['providers'].each do |provider|
      provider['models'].each do |model|
        benchmarks << LLMBenchmark.new(provider['name'], model['nickname'], @print_result)
      end
    end

    benchmarks
  end

  def run_parallel(benchmarks)
    results = []
    mutex = Mutex.new

    threads = benchmarks.map do |benchmark|
      Thread.new do
        result = benchmark.run_benchmark_for_results
        mutex.synchronize { results << result }
      end
    end

    threads.each(&:join)
    results
  end

  def display_results_table(results)
    # Sort results by tokens per second (descending)
    sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

    # Calculate column widths
    provider_width = sorted_results.map { |r| r[:provider].length }.max
    model_width = sorted_results.map { |r| r[:model].length }.max
    tokens_width = 12
    tps_width = 15

    # Table header
    if @print_result
      header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} | Message Content"
      separator = "| #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tokens_width} | #{'-' * tps_width} | #{'-' * 80}"
    else
      header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} |"
      separator = "| #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tokens_width} | #{'-' * tps_width} |"
    end

    puts header
    puts separator

    # Table rows
    sorted_results.each do |result|
      provider_col = result[:provider].ljust(provider_width)
      model_col = result[:model].ljust(model_width)

      if result[:success]
        tokens_col = result[:total_tokens].to_s.rjust(tokens_width)
        tps_col = result[:tokens_per_second].to_s.rjust(tps_width)

        if @print_result
          message_content = result[:message_content][0..79]
          puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} | #{message_content}"
        else
          puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} |"
        end
      else
        tokens_col = "ERROR".rjust(tokens_width)
        tps_col = "FAILED".rjust(tps_width)

        if @print_result
          puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} | #{result[:error][0..79]}"
        else
          puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} |"
        end
      end
    end

    puts
  end

  def display_summary(results)
    successful = results.select { |r| r[:success] }
    failed = results.select { |r| !r[:success] }

    puts "=== Summary ==="
    puts "Total benchmarks: #{results.length}"
    puts "Successful: #{successful.length}"
    puts "Failed: #{failed.length}"

    if successful.any?
      avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
      fastest = successful.max_by { |r| r[:tokens_per_second] }
      slowest = successful.min_by { |r| r[:tokens_per_second] }

      puts "Average tokens/sec: #{avg_tps.round(2)}"
      puts "Fastest: #{fastest[:provider]}/#{fastest[:model]} (#{fastest[:tokens_per_second]} tokens/sec)"
      puts "Slowest: #{slowest[:provider]}/#{slowest[:model]} (#{slowest[:tokens_per_second]} tokens/sec)"
    end

    if failed.any?
      puts "\nFailed benchmarks:"
      failed.each do |result|
        puts "  #{result[:provider]}/#{result[:model]}: #{result[:error]}"
      end
    end
  end
end

class Tracker
  def initialize(config)
    @config = config
    @csv_file = "llm_benchmark_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
    @running = true
    @next_run_time = Time.now
    setup_signal_handlers
  end

  def start_tracking
    puts "=== LLM Performance Tracker ==="
    puts "Tracking all models every 60 seconds"
    puts "Results will be saved to: #{@csv_file}"
    puts "Press Ctrl+C to stop tracking"
    puts

    # Initialize CSV file with header
    initialize_csv

    # Run first benchmark immediately
    run_tracking_cycle

    # Start continuous tracking loop
    while @running
      # Calculate time until next run
      time_until_next_run = @next_run_time - Time.now

      if time_until_next_run > 0
        # Sleep in small intervals to check for signals frequently
        sleep_time = [time_until_next_run, 1.0].min
        sleep(sleep_time)
      else
        # Time to run the tracking cycle
        run_tracking_cycle
        # Set next run time for 60 seconds from now
        @next_run_time = Time.now + 60
      end
    end

    puts "\nTracking stopped by user"
    puts "Results saved to: #{@csv_file}"
  end

  private

  def setup_signal_handlers
    Signal.trap('INT') do
      @running = false
      puts "\nStopping tracking..."
    end

    Signal.trap('TERM') do
      @running = false
      puts "\nStopping tracking..."
    end
  end

  def initialize_csv
    File.open(@csv_file, 'w') do |file|
      file.write("timestamp,provider_model,tokens_per_second,total_tokens,duration_seconds\n")
    end
  end

  def run_tracking_cycle
    timestamp = Time.now
    puts "[#{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] Running benchmark cycle..."

    parallel_benchmark = ParallelBenchmark.new(@config)
    results = parallel_benchmark.run_silent

    write_results_to_csv(timestamp, results)
    display_cycle_summary(results)
  end

  def write_results_to_csv(timestamp, results)
    File.open(@csv_file, 'a') do |file|
      results.each do |result|
        if result[:success]
          provider_model = "#{result[:provider]}+#{result[:model]}"
          csv_line = [
            timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            provider_model,
            result[:tokens_per_second],
            result[:total_tokens],
            result[:duration]
          ].join(',') + "\n"
          file.write(csv_line)
        end
      end
    end
  end

  def display_cycle_summary(results)
    successful = results.select { |r| r[:success] }
    failed = results.select { |r| !r[:success] }

    puts "  Completed: #{successful.length} successful, #{failed.length} failed"

    if successful.any?
      avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
      puts "  Average tokens/sec: #{avg_tps.round(2)}"
    end

    if failed.any?
      puts "  Failed: #{failed.map { |f| "#{f[:provider]}/#{f[:model]}" }.join(', ')}"
    end

    puts "\n  === Individual Model Results ==="

    # Sort results by tokens per second (descending)
    sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

    # Calculate column widths
    provider_width = sorted_results.map { |r| r[:provider].length }.max
    model_width = sorted_results.map { |r| r[:model].length }.max
    tokens_width = 12
    tps_width = 15
    duration_width = 12

    # Table header
    header = "  | #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Tokens/sec".rjust(tps_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Duration".rjust(duration_width)} |"
    separator = "  | #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tps_width} | #{'-' * tokens_width} | #{'-' * duration_width} |"

    puts header
    puts separator

    # Table rows
    sorted_results.each do |result|
      provider_col = result[:provider].ljust(provider_width)
      model_col = result[:model].ljust(model_width)

      if result[:success]
        tps_col = result[:tokens_per_second].to_s.rjust(tps_width)
        tokens_col = result[:total_tokens].to_s.rjust(tokens_width)
        duration_col = "#{result[:duration]}s".rjust(duration_width)
        puts "  | #{provider_col} | #{model_col} | #{tps_col} | #{tokens_col} | #{duration_col} |"
      else
        tps_col = "FAILED".rjust(tps_width)
        tokens_col = "ERROR".rjust(tokens_width)
        duration_col = "N/A".rjust(duration_width)
        puts "  | #{provider_col} | #{model_col} | #{tps_col} | #{tokens_col} | #{duration_col} |"
      end
    end
  end
end

def parse_arguments
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} --provider PROVIDER --model NICKNAME [--print-result]"
    opts.banner += "\n       #{$PROGRAM_NAME} --all [--track] [--print-result]"

    opts.on('--provider PROVIDER', 'Provider name from models.yaml') do |provider|
      options[:provider] = provider
    end

    opts.on('--model NICKNAME', 'Model nickname from models.yaml') do |model|
      options[:model] = model
    end

    opts.on('--all', 'Run benchmark on all configured models') do
      options[:all] = true
    end

    opts.on('--track', 'Enable continuous tracking with CSV output (requires --all)') do
      options[:track] = true
    end

    opts.on('--print-result', 'Print the full message returned by each LLM') do
      options[:print_result] = true
    end

    opts.on('--help', 'Display help') do
      puts opts
      exit
    end
  end.parse!

  if options[:track] && !options[:all]
    puts "Error: --track requires --all"
    puts "Use --help for usage information"
    exit 1
  end

  if options[:all]
    options
  elsif options[:provider] && options[:model]
    options
  else
    puts "Error: Either --provider and --model, or --all is required"
    puts "Use --help for usage information"
    exit 1
  end

  options
end

def main
  begin
    options = parse_arguments

    if options[:all]
      config = YAML.load_file(File.join(__dir__, 'models.yaml'))

      if options[:track]
        tracker = Tracker.new(config)
        tracker.start_tracking
      else
        parallel_benchmark = ParallelBenchmark.new(config, options[:print_result])
        parallel_benchmark.run_all
      end
    else
      benchmark = LLMBenchmark.new(options[:provider], options[:model], options[:print_result])
      benchmark.run_benchmark
    end
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end
end

if __FILE__ == $0
  main
end
