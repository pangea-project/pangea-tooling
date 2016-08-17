module Debian
  # A debian patch series as seen in debian/patches/series
  class PatchSeries
    attr_reader :patches

    def initialize(package_path, filename = 'series')
      @package_path = package_path
      @filename = filename
      raise 'not a package path' unless Dir.exist?("#{package_path}/debian")
      @patches = []
      parse
    end

    def exist?
      @exist ||= false
    end

    private

    def parse
      path = "#{@package_path}/debian/patches/#{@filename}"
      return unless (@exist = File.exist?(path))
      data = File.read(path)
      data.split($/).each do |line|
        next if line.chop.strip.empty? || line.start_with?('#')
        # series names really shouldn't use paths, so strip by space. This
        # enforces the simple series format described in the dpkg-source manpage
        # which unlike quilt does not support additional arguments such as
        # -pN.
        @patches << line.split(' ').first
      end
    end
  end
end
