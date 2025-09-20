# frozen_string_literal: true

require "colorize"

module LLMBench
  module Colors
    # Colors for different elements
    HEADER = :cyan
    SUCCESS = :green
    ERROR = :red
    WARNING = :yellow
    INFO = :blue
    METRIC = :magenta
    HIGHLIGHT = :light_blue
    BORDER = :white

    # Predefined color methods
    def self.header(text)
      text.colorize(HEADER)
    end

    def self.success(text)
      text.colorize(SUCCESS)
    end

    def self.error(text)
      text.colorize(ERROR)
    end

    def self.warning(text)
      text.colorize(WARNING)
    end

    def self.info(text)
      text.colorize(INFO)
    end

    def self.metric(text)
      text.colorize(METRIC)
    end

    def self.highlight(text)
      text.colorize(HIGHLIGHT)
    end

    def self.border(text)
      text.colorize(BORDER)
    end
  end
end
