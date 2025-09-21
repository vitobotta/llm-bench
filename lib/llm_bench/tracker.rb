# frozen_string_literal: true

require_relative "colors"

module LLMBench
  class Tracker
    def initialize(config_manager:, interval: 600)
      @config_manager = config_manager
      @config = config_manager.config
      @csv_file = "llm_benchmark_results_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
      @running = true
      @next_run_time = Time.now
      @interval = interval
      @results_formatter = ResultsFormatter.new(print_result: false)
      setup_signal_handlers
    end

    def start_tracking
      puts Colors.header("=== LLM Performance Tracker ===")
      puts Colors.info("Tracking all models every #{interval} seconds")
      puts Colors.info("Results will be saved to: #{csv_file}")
      puts Colors.highlight("Press Ctrl+C to stop tracking")
      puts

      initialize_csv

      run_tracking_cycle

      while running
        time_until_next_run = next_run_time - Time.now

        if time_until_next_run.positive?
          sleep_time = [time_until_next_run, 1.0].min
          sleep(sleep_time)
        else
          run_tracking_cycle
          @next_run_time = Time.now + interval
        end
      end

      puts "\n#{Colors.warning('Tracking stopped by user')}"
      puts Colors.info("Results saved to: #{csv_file}")
    end

    private

    attr_reader :csv_file, :running, :next_run_time, :config, :config_manager, :results_formatter, :interval

    def setup_signal_handlers
      Signal.trap("INT") do
        puts "\n#{Colors.warning('Received interrupt signal, exiting immediately...')}"
        exit 0
      end

      Signal.trap("TERM") do
        puts "\n#{Colors.warning('Received termination signal, exiting immediately...')}"
        exit 0
      end
    end

    def initialize_csv
      File.write(csv_file, "timestamp,provider_model,tokens_per_second,total_tokens,duration_seconds\n")
    end

    def run_tracking_cycle
      timestamp = Time.now
      puts "#{Colors.border("[#{timestamp.strftime('%Y-%m-%d %H:%M:%S')}]")} #{Colors.highlight('Running benchmark cycle...')}"

      parallel_benchmark = ParallelBenchmark.new(config_manager:, print_result: false)
      results = parallel_benchmark.run_silent

      write_results_to_csv(timestamp:, results:)
      results_formatter.display_cycle_summary(results)
    end

    def write_results_to_csv(timestamp:, results:)
      File.open(csv_file, "a") do |file|
        results.each do |result|
          next unless result[:success]

          provider_model = "#{result[:provider]}: #{result[:model]}"
          csv_line = [
            timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            provider_model,
            result[:tokens_per_second],
            result[:total_tokens],
            result[:duration]
          ].join(",") << "\n"
          file.write(csv_line)
        end
      end
    end
  end
end
