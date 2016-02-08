require 'yaml'

require_relative '../deprecate'

module CI
  # A PatternArray.
  # PatternArray is a specific Array meant to be used for Pattern objects.
  # PatternArray includes PatternFilter to filter patterns that do not match
  # a reference value.
  # class PatternArray < Array
  #   include PatternFilter
  # end

  # Base class for all patterns
  class PatternBase
    attr_reader :pattern

    def initialize(pattern)
      @pattern = pattern
    end

    # Compare self to other.
    # Patterns are
    #   - equal when self matches other and other matches self
    #   - lower than when other matches self (i.e. self is more concrete)
    #   - greater than when self matches other (i.e. self is less concrete)
    #   - uncomparable when other is not a Pattern or none of the above applies,
    #     in which case they are both Patterns but incompatible ones.
    #     For example vivid_* and utopic_* do not match one another and thus
    #     can not be sorted according the outline here.
    # Sorting pattern thusly means that the lowest pattern is the most concrete
    # pattern.
    def <=>(other)
      return nil unless other.is_a?(PatternBase)
      if match?(other)
        return 0 if other.match?(self)
        return 1
      end
      # We don't match other. If other matches us other is greater.
      return -1 if other.match?(self)
      # If we don't match other and other doesn't match us then the patterns are
      # not comparable
      nil
    end

    # Convenience equality.
    # Patterns are considered equal when compared with another Pattern object
    # with which the pattern attribute matches. When compared with a String that
    # matches the pattern attribute. Otherwise defers to super.
    def ==(other)
      return true if other.respond_to?(:pattern) && other.pattern == @pattern
      return true if other.is_a?(String) && other == @pattern
      super(other)
    end

    def to_s
      @pattern.to_s
    end

    # FIXME returns difference on what you put in
    def self.filter(reference, enumerable)
      if reference.respond_to?(:reject!)
        enumerable.each do |e, *|
          reference.reject! { |k, *| e.match?(k) }
        end
        return reference
      end
      enumerable.reject { |k, *| !k.match?(reference) }
    end

    def self.sort_hash(enumerable)
      enumerable.class[enumerable.sort_by { |pattern, *_| pattern }]
    end

    # Constructs a new Hash with the values converted in Patterns.
    # @param hash a Hash to covert into a PatternHash
    # @param recurse whether or not to recursively convert hash
    def self.convert_hash(hash, recurse: true)
      new_hash = {}
      hash.each_with_object(new_hash) do |(key, value), memo|
        if recurse && value.is_a?(Hash)
          value = convert_hash(value, recurse: recurse)
        end
        memo[new(key)] = value
        memo
      end
      new_hash
    end
  end

  # A POSIX regex match pattern.
  # Pattern matching is implemented by File.fnmatch and reperesents a POSIX
  # regex match. Namely a simplified regex as often used for file or path
  # patterns.
  class FNMatchPattern < PatternBase
    # @param reference [String] reference the pattern might match
    # @return true if the pattern matches the refernece
    def match?(reference)
      reference = reference.pattern if reference.respond_to?(:pattern)
      File.fnmatch(@pattern, reference)
    end
  end

  # @deprecated use FNMatchPattern
  class Pattern < FNMatchPattern # Compat
    extend Deprecate
    def initialize(*args)
      super
    end
    deprecate :initialize, :FNMatchPattern, 2016, 02
  end

  # Simple .include? pattern. An instance of this pattern matches a reference
  # if it is included in the reference in any form or fashion at any given
  # location. It is therefore less accurate than the FNMatchPattern but more
  # convenient to handle if all patterns are meant to essentially be matches of
  # the form "*pat*".
  class IncludePattern < PatternBase
    # @param reference [String] reference the pattern might match
    # @return true if the pattern matches the refernece
    def match?(reference)
      reference = reference.pattern if reference.respond_to?(:pattern)
      reference.include?(pattern)
    end
  end
end
