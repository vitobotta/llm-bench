require_relative 'parallel_benchmark'

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

    initialize_csv

    run_tracking_cycle

    while @running
      time_until_next_run = @next_run_time - Time.now

      if time_until_next_run.positive?
        sleep_time = [time_until_next_run, 1.0].min
        sleep(sleep_time)
      else
        run_tracking_cycle
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
        next unless result[:success]

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

    sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

    provider_width = sorted_results.map { |r| r[:provider].length }.max
    model_width = sorted_results.map { |r| r[:model].length }.max
    tokens_width = 12
    tps_width = 15
    duration_width = 12

    header = "  | #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Tokens/sec".rjust(tps_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Duration".rjust(duration_width)} |"
    separator = "  | #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tps_width} | #{'-' * tokens_width} | #{'-' * duration_width} |"

    puts header
    puts separator

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