# frozen_string_literal: true

require_relative "colors"

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

      puts Colors.header(header)
      puts Colors.border(separator)

      display_table_rows(sorted_results, provider_width:, model_width:, tokens_width:, tps_width:)
      puts
    end

    def display_summary(results)
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

      puts Colors.header("=== Summary ===")
      puts Colors.info("Total benchmarks: #{results.length}")
      puts Colors.success("Successful: #{successful.length}")
      puts Colors.error("Failed: #{failed.length}")

      display_performance_metrics(successful) if successful.any?

      display_failed_benchmarks(failed) if failed.any?
    end

    def display_cycle_summary(results)
      successful = results.select { |r| r[:success] }
      failed = results.reject { |r| r[:success] }

      puts "  #{Colors.success("Completed: #{successful.length} successful")}, #{Colors.error("#{failed.length} failed")}"

      if successful.any?
        avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
        puts "  #{Colors.metric("Average tokens/sec: #{avg_tps.round(2)}")}"
      end

      puts "  #{Colors.error("Failed: #{failed.map { |f| "#{f[:provider]}/#{f[:model]}" }.join(", ")}")}" if failed.any?

      display_individual_results(results) if results.any?
    end

    private

    attr_reader :print_result

    def calculate_column_width(results, column)
      results.map { |r| r[column].length }.max
    end

    def build_table_header(provider_width:, model_width:, tokens_width:, tps_width:)
      if print_result
        header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} | Message Content"
        separator = "| #{"-" * provider_width} | #{"-" * model_width} | #{"-" * tokens_width} | #{"-" * tps_width} | #{"-" * 80}"
      else
        header = "| #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | #{"Total Tokens".rjust(tokens_width)} | #{"Tokens/sec".rjust(tps_width)} |"
        separator = "| #{"-" * provider_width} | #{"-" * model_width} | #{"-" * tokens_width} | #{"-" * tps_width} |"
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

      if print_result
        message_content = result[:message_content][0..79]
        puts "| #{Colors.success(provider_col)} | #{Colors.success(model_col)} | #{Colors.metric(tokens_col)} | #{Colors.success(tps_col)} | #{Colors.border(message_content)}"
      else
        puts "| #{Colors.success(provider_col)} | #{Colors.success(model_col)} | #{Colors.metric(tokens_col)} | #{Colors.success(tps_col)} |"
      end
    end

    def display_failed_row(result, provider_col:, model_col:, tokens_width:, tps_width:)
      tokens_col = Colors.error("ERROR".rjust(tokens_width))
      tps_col = Colors.error("FAILED".rjust(tps_width))

      if print_result
        puts "| #{Colors.error(provider_col)} | #{Colors.error(model_col)} | #{tokens_col} | #{tps_col} | #{Colors.border(result[:error][0..79])}"
      else
        puts "| #{Colors.error(provider_col)} | #{Colors.error(model_col)} | #{tokens_col} | #{tps_col} |"
      end
    end

    def display_performance_metrics(successful)
      avg_tps = successful.map { |r| r[:tokens_per_second] }.sum / successful.length
      fastest = successful.max_by { |r| r[:tokens_per_second] }
      slowest = successful.min_by { |r| r[:tokens_per_second] }

      puts Colors.metric("Average tokens/sec: #{avg_tps.round(2)}")
      puts Colors.success("Fastest: #{fastest[:provider]}/#{fastest[:model]} (#{fastest[:tokens_per_second]} tokens/sec)")
      puts Colors.warning("Slowest: #{slowest[:provider]}/#{slowest[:model]} (#{slowest[:tokens_per_second]} tokens/sec)")
    end

    def display_failed_benchmarks(failed)
      puts "\n#{Colors.error("Failed benchmarks:")}"
      failed.each do |result|
        puts "  #{Colors.error("#{result[:provider]}/#{result[:model]}")}: #{Colors.warning(result[:error])}"
      end
    end

    def display_individual_results(results)
      puts "\n  #{Colors.header('=== Individual Model Results ===')}"

      sorted_results = results.sort_by { |r| -r[:tokens_per_second] }

      provider_width = calculate_column_width(sorted_results, :provider)
      model_width = calculate_column_width(sorted_results, :model)
      tokens_width = 12
      tps_width = 15
      duration_width = 12

      header = "  | #{"Provider".ljust(provider_width)} | #{"Model".ljust(model_width)} | " \
               "#{"Tokens/sec".rjust(tps_width)} | #{"Total Tokens".rjust(tokens_width)} | " \
               "#{"Duration".rjust(duration_width)} |"
      separator = "  | #{"-" * provider_width} | #{"-" * model_width} | " \
                  "#{"-" * tps_width} | #{"-" * tokens_width} | " \
                  "#{"-" * duration_width} |"

      puts Colors.header(header)
      puts Colors.border(separator)

      sorted_results.each do |result|
        provider_col = result[:provider].ljust(provider_width)
        model_col = result[:model].ljust(model_width)

        if result[:success]
          tps_col = Colors.success(result[:tokens_per_second].to_s.rjust(tps_width))
          tokens_col = Colors.metric(result[:total_tokens].to_s.rjust(tokens_width))
          duration_col = Colors.info("#{result[:duration]}s".rjust(duration_width))
        else
          tps_col = Colors.error("FAILED".rjust(tps_width))
          tokens_col = Colors.error("ERROR".rjust(tokens_width))
          duration_col = Colors.warning("N/A".rjust(duration_width))
        end
        puts "  | #{Colors.info(provider_col)} | #{Colors.info(model_col)} | #{tps_col} | #{tokens_col} | #{duration_col} |"
      end
    end
  end
end
