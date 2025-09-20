# frozen_string_literal: true

require_relative "colors"

module LLMBench
  class ParallelBenchmark
    def initialize(config_manager:, print_result: false)
      @config_manager = config_manager
      @config = config_manager.config
      @print_result = print_result
      @benchmark_factory = BenchmarkFactory.new(config_manager:, print_result:)
      @results_formatter = ResultsFormatter.new(print_result:)
    end

    def run_all
      puts Colors.header("=== LLM Benchmark ===")
      puts Colors.info("Running benchmarks on all configured models...")
      puts Colors.border("Starting at #{Time.now.strftime("%Y-%m-%d %H:%M:%S.%3N")}")
      puts

      benchmarks = create_benchmarks
      results = run_parallel(benchmarks:)

      results_formatter.display_results_table(results)
      results_formatter.display_summary(results)
    end

    def run_silent
      benchmarks = create_benchmarks
      run_parallel(benchmarks:)
    end

    private

    attr_reader :print_result, :config, :config_manager, :benchmark_factory, :results_formatter

    def create_benchmarks
      benchmark_factory.create_all_benchmarks
    end

    def run_parallel(benchmarks:)
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
  end
end
