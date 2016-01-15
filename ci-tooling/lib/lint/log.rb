require_relative 'log/cmake'
require_relative 'log/lintian'
require_relative 'log/list_missing'

module Lint
  # Lints a build log
  class Log
    attr_reader :log_data

    def initialize(log_data)
      @log_data = log_data
    end

    # @return [Array<Result>]
    def lint
      results = []
      [CMake, Lintian, ListMissing].each do |klass|
        results << klass.new.lint(@log_data.clone)
      end
      results
    end
  end
end
