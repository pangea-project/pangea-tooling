module ProjectsFactoryCommon
  def split_hash(hash)
    clean_hash(*hash.first)
  end

  def each_pattern_value(subset)
    subset.each do |sub|
      pattern = sub.keys[0]
      value = sub.values[0]
      yield pattern, value
    end
  end

  def from_hash(hash)
    base, subset = split_hash(hash)
    raise 'not array' unless subset.is_a?(Array)

    selection = self.class.ls(base).collect do |name|
      matches = match_path_to_subsets(base, name, subset)
      # Get best matching pattern.
      CI::PatternBase.sort_hash(matches).values[0]
    end
    selection.compact.collect { |s| from_string(*s) }
  end

  def match_path_to_subsets(base, name, subset)
    matches = {}
    each_pattern_value(subset) do |pattern, value|
      next unless pattern.match?(name)
      match = ["#{base}/#{name}", value]
      matches[pattern] = match
    end
    matches
  end

  def clean_hash(base, subset)
    subset.collect! do |sub|
      # Coerce flat strings into hash. This makes handling more consistent
      # further down the line. Flat strings simply have empty properties {}.
      sub = sub.is_a?(Hash) ? sub : { sub => {} }
      # Convert the subset into a pattern matching set by converting the
      # keys into suitable patterns.
      key = sub.keys[0]
      sub[CI::FNMatchPattern.new(key.to_s)] = sub.delete(key)
      sub
    end
    [base, subset]
  end

  def from_string(str, params = {})
    kwords = params(str)
    kwords.merge!(symbolize(params))
    puts "new_project(#{kwords})"
    new_project(**kwords)
  rescue Project::GitTransactionError, RuntimeError => e
    p e
    nil
  end
end
