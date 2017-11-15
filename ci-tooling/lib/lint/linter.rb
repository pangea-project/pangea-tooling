# frozen_string_literal: true

require 'yaml'

require_relative '../ci/pattern'
require_relative 'result'

module Lint
  # Base class for all linters.
  # This class primarily features helpers to load ignore patterns.
  class Linter
    attr_accessor :ignores

    def initialize
      @ignores = []
    end

    # Loads cmake-ignore as a YAML file and ignore series as specified
    # or if it's not a YAML list revert back to basic style
    def load_include_ignores(file_path)
      return unless File.exist?(file_path)
      cmake_yaml = YAML.load_file(file_path)
      # Our YAML has to be an Array else we'll go back to basic style
      if cmake_yaml.instance_of?(Array)
        load_include_ignores_yaml(cmake_yaml)
      else # compat old files
        load_include_ignores_basic(file_path)
      end
    end

    private

    # It's YAML, load it as such.
    def load_include_ignores_yaml(data)
      data.each do |ignore_entry|
        if ignore_entry.is_a?(String)
          @ignores << CI::IncludePattern.new(ignore_entry)
        elsif ignore_entry['series'] == ENV.fetch('DIST')
          @ignores << CI::IncludePattern.new(ignore_entry.keys[0])
        end
      end
    end

    # It's not YAML, load it old school
    def load_include_ignores_basic(file_path)
      File.read(file_path).strip.split($/).each do |line|
        next if line.strip.start_with?('#') || line.empty?
        @ignores << CI::IncludePattern.new(line)
      end
    end
  end
end
