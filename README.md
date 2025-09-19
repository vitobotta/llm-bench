# LLMBench

A Ruby gem for benchmarking and comparing the performance of different Large Language Model providers and APIs.

## Features

- Support for both OpenAI and Anthropic-compatible API formats
- Parallel execution across multiple models and providers
- Continuous tracking with CSV export functionality
- Clean, modular architecture with proper gem structure
- No external dependencies - uses only Ruby standard library

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llm_bench'
```

And then execute:
```bash
bundle install
```

Or install it yourself as:
```bash
gem install llm_bench
```

## Usage

### Configuration

Create a configuration file named `models.yaml` in your current directory, or specify a custom path with the `--config` argument:

```yaml
prompt: "Explain the concept of machine learning in simple terms in exactly 300 words..."

providers:
  - name: "openai"
    base_url: "https://api.openai.com/v1"
    api_key: "your-api-key-here"
    models:
      - nickname: "gpt-4"
        id: "gpt-4"
        api_format: "openai"

  - name: "anthropic"
    base_url: "https://api.anthropic.com"
    api_key: "your-api-key-here"
    models:
      - nickname: "claude"
        id: "claude-3-sonnet-20240229"
        api_format: "anthropic"
```

### Commands

#### Benchmark a single model:
```bash
llm_bench --config ./my-config.yaml --provider openai --model gpt-4
```

#### Benchmark all configured models:
```bash
llm_bench --all
```

#### Benchmark all models with custom config:
```bash
llm_bench --config ./my-config.yaml --all
```

#### Enable continuous tracking:
```bash
llm_bench --config ./my-config.yaml --all --track
```

#### Print full responses:
```bash
llm_bench --config ./my-config.yaml --provider openai --model gpt-4 --print-result
```

**Note**: If no `--config` argument is provided, `llm_bench` will look for `models.yaml` in the current directory. If the configuration file is not found, an error will be displayed.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To build and install the gem locally:

```bash
gem build llm_bench.gemspec
gem install ./llm_bench-0.1.0.gem
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vito/llm-bench.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).