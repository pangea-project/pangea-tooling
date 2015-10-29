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

    # Tagging arguments for Image.tag.
    # @example Can be used like this
    #    image = Image.get('yolo')
    #    image.tag(PangeaImage.new(:ubuntu, :vivid).tag_args)
    # @example You can also freely merge into the arguments
    #    image.tag(pimage.merge(force: true))
    # @return [Hash] tagging arguments for Image.tag
    def tag_args
      { repo: repo, tag: tag }
    end

    def to_s
      to_str
    end

    def to_str
      "#{@@namespace}/#{@flavor}:#{@tag}"
    end
  end
end
