# frozen_string_literal: true
require_relative '../ci/pattern'
require_relative 'result'
require 'yaml'
require 'pp'

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
      begin
        cmake_yaml = YAML.load(File.read(file_path))
        #Our YAML has to be a list else we'll go back to basic style
        if not cmake_yaml.instance_of?(Array)
          load_include_ignores_basic(file_path)
        else
          cmake_yaml.each do |ignore_entry|
            if ignore_entry.is_a?(String)
              @ignores << CI::IncludePattern.new(ignore_entry)
            elsif ignore_entry['series'] == ENV['DIST']
              @ignores << CI::IncludePattern.new(ignore_entry.keys[0])
            end
          end
        end
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
        load_include_ignores_basic(file_path)
      end
    end

    # it's not YAML, load it old school
    def load_include_ignores_basic(file_path)
      File.read(file_path).strip.split($/).each do |line|
        next if line.strip.start_with?('#') || line.empty?
        @ignores << CI::IncludePattern.new(line)
      end
    end
  end
end
