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

    def uniq
      @errors.uniq!
      @warnings.uniq!
      @informations.uniq!
      self
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
end
