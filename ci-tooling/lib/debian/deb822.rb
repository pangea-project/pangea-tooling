# Helper class that ignores the case on its key.
class CaseHash < Hash
  def [](key)
    key.respond_to?(:downcase) ? super(key.downcase) : super(key)
  end

  def []=(key, value)
    key.respond_to?(:downcase) ? super(key.downcase, value) : super(key, value)
  end

  def key?(key)
    key.respond_to?(:downcase) ? super(key.downcase) : super(key)
  end

  def fetch(key, default)
    key.respond_to?(:downcase) ? super(key.downcase, default) : super(key, default)
  end
end

module Debian
  # A package relationship.
  class Relationship
    attr_reader :name
    attr_reader :operator
    attr_reader :version

    def initialize(string)
      @name = nil
      @operator = nil
      @version = nil

      string.strip!
      return if string.empty?

      # Fancy plain text description:
      # - Start of line
      # - any word character, at least once
      # - 0-n space characters
      # - at the most once:
      #  - (
      #  - any of the version operators, but only once
      #  - anything before closing ')'
      #  - )
      # Random note: all matches are stripped, so we don't need to
      #              handle whitespaces being in the matches.
      match = string.match(/^(\S+)\s*(\((<|<<|<=|=|>=|>>|>){1}(.*)\))?/)
      # 0 full match
      # 1 name
      # 2 version definition (or nil)
      # 3  operator
      # 4  version
      @name = match[1] ? match[1].strip : nil
      @operator = match[3] ? match[3].strip : nil
      @version = match[4] ? match[4].strip : nil
    end
  end

  class Deb822
    def parse_relationships(line)
      ret = []
      line.split(',').each do |string|
        r = Relationship.new(string)
        next unless r.name # Invalid name, ignore this bugger.
        ret << r
      end
      ret
    end

    def parse_paragraph(lines, fields = {})
      mandatory_fields = fields[:mandatory] || []
      multiline_fields = fields[:multiline] || []
      foldable_fields = fields[:foldable] || []
      relationship_fields = fields[:relationship] || []

      current_header = nil
      data = CaseHash.new

      while (line = lines.shift) && line && !line.strip.empty?
        next if line.start_with?('#') # Comment

        header_match = line.match(/^(\S+):(.*)/)
        unless header_match.nil?
          # 0 = full match
          # 1 = key match
          # 2 = value match
          key = header_match[1].lstrip
          value = header_match[2].lstrip
          current_header = key
          if relationship_fields.include?(key.downcase)
            value = parse_relationships(value)
          elsif foldable_fields.include?(key.downcase)
            value = [value.chomp(',').strip]
          end
          data[key] = value
          next
        end

        fold_match = line.match(/^\s+(.+\n)$/)
        unless fold_match.nil?
          # Folding value encountered -> append to header.
          # 0 full match
          # 1 value match
          value = fold_match[1].lstrip

          # Fold matches can either be proper RFC 5322 folds or
          # multiline continuations, latter wants to preserve
          # newlines and so forth.
          # The type is entirely dependent on what the header field is.
          if foldable_fields.include?(current_header.downcase)
            # We do not care about whitespaces for folds, so strip everything.
            if relationship_fields.include?(current_header.downcase)
              value = parse_relationships(value)
            else
              value = [value.strip]
            end
            data[current_header] += value
          elsif multiline_fields.include?(current_header.downcase)
            # For multiline we want to preserve right hand side whitespaces.
            data[current_header] << value
          else
            fail "A field is folding that is not allowed to #{current_header}"
          end

          next
        end

        # TODO: user defined fields

        fail "Paragraph parsing ran into an unknown line: '#{line}'"
      end

      # If the entire stanza was commented out we can end up with no data, it
      # is very sad.
      return nil if data.empty?

      mandatory_fields.each do |field|
        # TODO: this should really make a list and complain all at once or
        # something.
        fail "Missing mandatory field #{field}" unless data.include?(field)
      end

      data
    end

    def parse!
      fail 'Not implemented'
    end
  end
end
