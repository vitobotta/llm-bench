#!/usr/bin/env ruby

require_relative 'lib/tracker'
require 'yaml'
require 'optparse'

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
    require_relative 'lib/llm_benchmark'
    benchmark = LLMBenchmark.new(options[:provider], options[:model], options[:print_result])
    benchmark.run_benchmark
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  exit 1
end

main if __FILE__ == $PROGRAM_NAME