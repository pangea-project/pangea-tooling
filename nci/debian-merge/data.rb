module NCI
  module DebianMerge
    class Data
      class << self
        def from_file
          new(JSON.parse(File.read('data.json')))
        end
      end

      def initialize(data)
        @data = data
      end

      def tag_base
        @data.fetch('tag_base')
      end

      def repos
        @data.fetch('repos')
      end
    end
  end
end
