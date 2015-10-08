module CI
  class PangeaImage
    attr_accessor :tag
    attr_accessor :flavor

    @@namespace = "pangea"

    def initialize(flavor, tag)
      @flavor = flavor
      @tag = tag
    end

    def namespace
      @@namespace
    end

    def self.namespace
      @@namespace
    end

    def self.namespace=(string)
      @@namespace = string
    end

    def repo
      "#{@@namespace}/#{@flavor}"
    end

    def to_s
      to_str
    end

    def to_str
      "#{@@namespace}/#{@flavor}:#{@tag}"
    end
  end
end
