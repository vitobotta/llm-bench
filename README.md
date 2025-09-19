# LLMBench

A standalone Ruby gem for benchmarking and comparing the performance of different Large Language Model providers and APIs.

## Features

- Support for both OpenAI and Anthropic-compatible API formats
- Parallel execution across multiple models and providers
- Continuous tracking with CSV export functionality
- No external dependencies - uses only Ruby standard library

## Installation

### Using Ruby (Recommended)

**Important**: This is a standalone executable gem, not a library for use in other applications. Install it system-wide:

```bash
gem install llm_bench
```

Do not add this gem to your application's Gemfile - it is designed to be used as a command-line tool only.

### Using Docker

If you don't have Ruby installed or prefer containerized environments, you can use the Docker image:

```bash
# Build the Docker image
docker build -t llm_bench .

# Or use the pre-built image
docker pull vitobotta/llm-bench:v1
```

The Docker image includes everything needed to run `llm_bench` without installing Ruby locally.

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

### Docker Usage

When using Docker, you need to mount your configuration file and any output directories:

```bash
# Benchmark a single model with Docker
docker run -v $(pwd)/my-config.yaml:/data/models.yaml \
           -v $(pwd)/results:/data/results \
           llm_bench --provider openai --model gpt-4

# Benchmark all models with Docker
docker run -v $(pwd)/models.yaml:/data/models.yaml \
           -v $(pwd)/results:/data/results \
           llm_bench --all

# Enable continuous tracking with Docker
docker run -v $(pwd)/models.yaml:/data/models.yaml \
           -v $(pwd)/results:/data/results \
           llm_bench --all --track
```

The Docker container uses `/data` as the working directory, so mount your config file to `/data/models.yaml` (or use the `--config` argument with the mounted path) and mount any directories where you want to save output files.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To build and install the gem locally:

```bash
gem build llm_bench.gemspec
gem install ./llm_bench-0.1.0.gem
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vitobotta/llm-bench.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
