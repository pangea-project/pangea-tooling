module Debian
  # debian/source representation
  class Source
    # Represents a dpkg-source format. See manpage.
    class Format
      attr_reader :version
      attr_reader :type

      def initialize(str)
        @version = '1'
        @type = nil
        parse(str) if str
      end

      def to_s
        return @version unless type
        "#{version} (#{type})"
      end

      private

      def parse(str)
        str = str.read if str.respond_to?(:read)
        str = File.read(str) if File.exist?(str)
        data = str.strip
        match = data.match(/(?<version>[^\s]+)(\s+\((?<type>.*)\))?/)
        @version = match[:version]
        @type = match[:type].to_sym if match[:type]
      end
    end

    attr_reader :format

    def initialize(package_path)
      @package_path = package_path
      raise 'not a package path' unless Dir.exist?("#{package_path}/debian")
      parse
    end

    private

    def parse
      @format = Format.new("#{@package_path}/debian/source/format")
    end
  end
end
