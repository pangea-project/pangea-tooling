module CI
  class BaseImage
    def initialize(flavor, series)
      @flavor = flavor
      @series = series
    end

    def to_s
      "pangea/#{@flavor}:#{@series}"
    end
  end
end
