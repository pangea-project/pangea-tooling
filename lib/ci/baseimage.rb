module CI
  class BaseImage
    attr_accessor :repo
    attr_accessor :tag

    def initialize(flavor, series)
      @repo = "pangea/#{flavor}"
      @tag = series
    end

    def to_s
      "#{@repo}:#{@tag}"
    end
  end
end
