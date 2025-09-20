# frozen_string_literal: true

module LLMBench
  class ResultsFormatter
    def initialize(print_result: false)
      @print_result = print_result
    end

    def display_results_table(results)
      sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

      provider_width = calculate_column_width(sorted_results, :provider)
      model_width = calculate_column_width(sorted_results, :model)
      tokens_width = 12
      tps_width = 15

      header, separator = build_table_header(provider_width:, model_width:, tokens_width:, tps_width:)

      puts header
      puts separator

      display_table_rows(sorted_results, provider_width:, model_width:, tokens_width:, tps_width:)
      puts
    end

    def display_summary(results)
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

      puts "=== Summary ==="
      puts "Total benchmarks: #{results.length}"
      puts "Successful: #{successful.length}"
      puts "Failed: #{failed.length}"

      if successful.any?
        display_performance_metrics(successful)
      end

      display_failed_benchmarks(failed) if failed.any?
    end

    def display_cycle_summary(results)
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

      puts "  Completed: #{successful.length} successful, #{failed.length} failed"

      if successful.any?
        avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
        puts "  Average tokens/sec: #{avg_tps.round(2)}"
      end

      puts "  Failed: #{failed.map { |f| "#{f[:provider]}/#{f[:model]}" }.join(', ')}" if failed.any?

      display_individual_results(results) if results.any?
    end

    private

    def calculate_column_width(results, column)
      results.map { |r| r[column].length }.max
    end

    def build_table_header(provider_width:, model_width:, tokens_width:, tps_width:)
      if @print_result
        header = "| #{'Provider'.ljust(provider_width)} | #{'Model'.ljust(model_width)} | #{'Total Tokens'.rjust(tokens_width)} | #{'Tokens/sec'.rjust(tps_width)} | Message Content"
        separator = "| #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tokens_width} | #{'-' * tps_width} | #{'-' * 80}"
      else
        header = "| #{'Provider'.ljust(provider_width)} | #{'Model'.ljust(model_width)} | #{'Total Tokens'.rjust(tokens_width)} | #{'Tokens/sec'.rjust(tps_width)} |"
        separator = "| #{'-' * provider_width} | #{'-' * model_width} | #{'-' * tokens_width} | #{'-' * tps_width} |"
      end
      [header, separator]
    end

    def display_table_rows(results, provider_width:, model_width:, tokens_width:, tps_width:)
      results.each do |result|
        provider_col = result[:provider].ljust(provider_width)
        model_col = result[:model].ljust(model_width)

        if result[:success]
          display_successful_row(result, provider_col:, model_col:, tokens_width:, tps_width:)
        else
          display_failed_row(result, provider_col:, model_col:, tokens_width:, tps_width:)
        end
      end
    end

    def display_successful_row(result, provider_col:, model_col:, tokens_width:, tps_width:)
      tokens_col = result[:total_tokens].to_s.rjust(tokens_width)
      tps_col = result[:tokens_per_second].to_s.rjust(tps_width)

      if @print_result
        message_content = result[:message_content][0..79]
        puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} | #{message_content}"
      else
        puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} |"
      end
    end

    def display_failed_row(result, provider_col:, model_col:, tokens_width:, tps_width:)
      tokens_col = "ERROR".rjust(tokens_width)
      tps_col = "FAILED".rjust(tps_width)

      if @print_result
        puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} | #{result[:error][0..79]}"
      else
        puts "| #{provider_col} | #{model_col} | #{tokens_col} | #{tps_col} |"
      end
    end

    def display_performance_metrics(successful)
      avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
      fastest = successful.max_by { |r| r[:tokens_per_second] }
      slowest = successful.min_by { |r| r[:tokens_per_second] }

      puts "Average tokens/sec: #{avg_tps.round(2)}"
      puts "Fastest: #{fastest[:provider]}/#{fastest[:model]} (#{fastest[:tokens_per_second]} tokens/sec)"
      puts "Slowest: #{slowest[:provider]}/#{slowest[:model]} (#{slowest[:tokens_per_second]} tokens/sec)"
    end

    def display_failed_benchmarks(failed)
      puts "\nFailed benchmarks:"
      failed.each do |result|
        puts "  #{result[:provider]}/#{result[:model]}: #{result[:error]}"
      end
    end

    def display_individual_results(results)
      puts "\n  === Individual Model Results ==="

      sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

      provider_width = calculate_column_width(sorted_results, :provider)
      model_width = calculate_column_width(sorted_results, :model)
      tokens_width = 12
      tps_width = 15
      duration_width = 12

      header = "  | #{'Provider'.ljust(provider_width)} | #{'Model'.ljust(model_width)} | " \
               "#{'Tokens/sec'.rjust(tps_width)} | #{'Total Tokens'.rjust(tokens_width)} | " \
               "#{'Duration'.rjust(duration_width)} |"
      separator = "  | #{'-' * provider_width} | #{'-' * model_width} | " \
                  "#{'-' * tps_width} | #{'-' * tokens_width} | " \
                  "#{'-' * duration_width} |"

      puts header
      puts separator

      sorted_results.each do |result|
        provider_col = result[:provider].ljust(provider_width)
        model_col = result[:model].ljust(model_width)

        if result[:success]
          tps_col = result[:tokens_per_second].to_s.rjust(tps_width)
          tokens_col = result[:total_tokens].to_s.rjust(tokens_width)
          duration_col = "#{result[:duration]}s".rjust(duration_width)
        else
          tps_col = "FAILED".rjust(tps_width)
          tokens_col = "ERROR".rjust(tokens_width)
          duration_col = "N/A".rjust(duration_width)
        end
        puts "  | #{provider_col} | #{model_col} | #{tps_col} | #{tokens_col} | #{duration_col} |"
      end
    end
  end
end