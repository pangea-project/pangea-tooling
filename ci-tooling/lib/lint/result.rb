module Lint
  # A lint result expressing its
  class Result
    attr_accessor :valid
    attr_accessor :errors
    attr_accessor :warnings
    attr_accessor :informations

    def initialize
      @valid = false
      @errors = []
      @warnings = []
      @informations = []
    end

    def merge!(other)
      @valid = other.valid unless @valid
      @errors += other.errors
      @warnings += other.warnings
      @informations += other.informations
    end

    def all
      @errors + @warnings + @informations
    end

    def ==(other)
      @valid == other.valid &&
        @errors == other.errors &&
        @warnings == other.warnings &&
        @informations == other.informations
    end
  end

  # Logs arary of results to stdout
  class ResultLogger
    attr_accessor :results

    # @param results [Result, Array<Result>] results to log
    def initialize(results)
      @results = ([*results] || [])
    end

    def log
      @results.each do |result|
        next unless result.valid
        result.errors.each { |s| puts_kci('E', s) }
        result.warnings.each { |s| puts_kci('W', s) }
        result.informations.each { |s| puts_kci('I', s) }
      end
    end

    def self.puts_kci(type, str)
      puts "KCI-#{type} :: #{str}"
    end

    private

    def puts_kci(type, str)
      self.class.puts_kci(type, str)
    end
  end
end
