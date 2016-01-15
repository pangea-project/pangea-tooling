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

    def load_include_ignores(file_path)
      return unless File.exist?(file_path)
      File.read(file_path).strip.split($/).each do |line|
        next if line.strip.start_with?('#') || line.empty?
        @ignores << CI::IncludePattern.new(line)
      end
    end
  end
end
