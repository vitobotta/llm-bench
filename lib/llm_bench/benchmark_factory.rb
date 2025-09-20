# frozen_string_literal: true

module LLMBench
  class BenchmarkFactory
    def initialize(config_manager:, print_result: false)
      @config_manager = config_manager
      @config = @config_manager.config
      @print_result = print_result
    end

    def create_all_benchmarks
      benchmarks = []

      @config["providers"].each do |provider|
        provider["models"].each do |model|
          benchmarks << create_benchmark(
            provider_name: provider["name"],
            model_nickname: model["nickname"]
          )
        end
      end

      benchmarks
    end

    def create_benchmark(provider_name:, model_nickname:)
      Benchmark.new(
        provider_name:,
        model_nickname:,
        print_result: @print_result,
        config_manager: @config_manager
      )
    end
  end
end