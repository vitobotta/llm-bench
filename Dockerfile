# Use official Ruby image
FROM ruby:3.4-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    yaml-dev \
    && rm -rf /var/cache/apk/*

# Copy all necessary files
COPY llm_bench.gemspec ./
COPY lib/ ./lib/
COPY exe/ ./exe/

# Create a simple gem build without git dependency
RUN ruby -e "require 'yaml'; require 'fileutils'; spec_content = File.read('llm_bench.gemspec'); spec_content.sub!(/spec\.files = .*?end/m, 'spec.files = Dir[\"lib/**/*\", \"exe/**/*\", \"*.gemspec\", \"*.md\"]'); File.write('llm_bench.gemspec', spec_content)"

# Build and install the gem
RUN gem build llm_bench.gemspec && \
    gem install ./llm_bench-*.gem

# Create a directory for user configs
RUN mkdir -p /data

# Set the default working directory to /data
WORKDIR /data

# Set entrypoint
ENTRYPOINT ["llm_bench"]

# Default command shows help
CMD ["--help"]