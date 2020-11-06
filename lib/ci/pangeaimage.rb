# frozen_string_literal: true
module CI
  # Convenience wrapper to construct and handle pangea image names.
  class PangeaImage
    attr_accessor :tag
    attr_accessor :flavor
    attr_accessor :variant

    class << self
      def namespace
        @namespace ||= 'pangea'
      end
      attr_writer :namespace
    end

    def initialize(flavor, tag)
      @flavor = flavor
      @tag = tag
      @variant = flavor_variant
    end

    def flavor_variant
      # TODO could probably drop the defaulting if we updated all tests
      # accordingly :|
      node_labels = ENV.fetch('NODE_LABELS', '').split
      return nil unless node_labels.include?('shared-node')

      # When the node is shared the diversion arch needs to be tagged via this
      # env var.
      ENV.fetch('PANGEA_FLAVOR_ARCH')
    end

    def repo
      suffix = ''
      suffix = "-#{variant}" if variant
      "#{self.class.namespace}/#{@flavor}#{suffix}"
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
      "#{repo}:#{tag}"
    end
  end
end
