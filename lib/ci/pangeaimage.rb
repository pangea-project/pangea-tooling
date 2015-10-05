module CI
  class PangeaImage
    attr_accessor :repo
    attr_accessor :tag
    attr_accessor :flavor

    def initialize(flavor, series)
      if ENV['TESTING']
        @repo = "pangea-testing/#{flavor}"
      else
        @repo = "pangea/#{flavor}"
      end
      @flavor = flavor
      @tag = series
    end

    def to_s
      to_str
    end

    def to_str
      "#{@repo}:#{@tag}"
    end
  end
end
