# frozen_string_literal: true

module LLMBench
  class ParallelBenchmark
    def initialize(config:, print_result: false)
      @config = config
      @print_result = print_result
    end

    def run_all
      puts "=== LLM Benchmark ==="
      puts "Running benchmarks on all configured models..."
      puts "Starting at #{Time.now.strftime("%Y-%m-%d %H:%M:%S.%3N")}"
      puts

      benchmarks = create_benchmarks
      results = run_parallel(benchmarks:)

      display_results_table(results:)
      display_summary(results:)
    end

    def run_silent
      benchmarks = create_benchmarks
      run_parallel(benchmarks:)
    end

    private

    def create_benchmarks
      benchmarks = []

      @config["providers"].each do |provider|
        provider["models"].each do |model|
          benchmarks << Benchmark.new(
            provider_name: provider["name"],
            model_nickname: model["nickname"],
            print_result: @print_result,
            config: @config
          )
        end
      end

      benchmarks
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

    def display_results_table(results:)
      sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

      provider_width = sorted_results.map { |r| r[:provider].length }.max
      model_width = sorted_results.map { |r| r[:model].length }.max
      tokens_width = 12
      tps_width = 15

      if @print_result
        header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} | Message Content"
        separator = "| #{"-" * provider_width} | #{"-" * model_width} | #{"-" * tokens_width} | #{"-" * tps_width} | #{"-" * 80}"
      else
        header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} |"
        separator = "| #{"-" * provider_width} | #{"-" * model_width} | #{"-" * tokens_width} | #{"-" * tps_width} |"
      end

      puts header
      puts separator

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

    def display_summary(results:)
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

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

      return unless failed.any?

      puts "\nFailed benchmarks:"
      failed.each do |result|
        puts "  #{result[:provider]}/#{result[:model]}: #{result[:error]}"
      end
    end
  end
end
