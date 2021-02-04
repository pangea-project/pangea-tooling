# frozen_string_literal: true
require_relative 'result'

module Lint
  # Lints the presence of symbols files
  class Symbols
    attr_reader :package_directory

    def initialize(package_directory = Dir.pwd)
      @package_directory = package_directory
    end

    # @return [Result]
    def lint
      result = Result.new
      result.valid = true
      Dir.glob("#{@package_directory}/lib*.install").each do |install_file|
        lint_install_file(result, install_file)
      end
      result
    end

    private

    def lint_install_file(result, file)
      dir = File.dirname(file)
      basename = File.basename(file, '.install')
      return unless int?(basename[-1]) # No number at the end = no public lib.
      return if File.exist?("#{dir}/#{basename}.symbols") ||
                File.exist?("#{dir}/#{basename}.symbols.amd64")
      result.errors << "Public library without symbols file: #{basename}"
      result
    end

    def int?(char)
      !Integer(char).nil?
    rescue
      false
    end
  end
end
