require 'pathname'

require_relative '../debian/patchseries'
require_relative 'result'

# NOTE: patches that are in the series but not the VCS cause build failures, so
#       they are not covered in this check

module Lint
  # Lints a debian patches seris file
  class Series
    EXCLUDES = %w(series ignore).freeze

    attr_reader :package_directory

    def initialize(package_directory = Dir.pwd)
      @package_directory = package_directory
      # series is lazy init'd because it does a path check. A bit meh.
      @patch_directory = File.join(@package_directory, 'debian/patches')
    end

    # @return [Result]
    def lint
      result = Result.new
      result.valid = true
      Dir.glob("#{@patch_directory}/**/*").each do |patch|
        next if EXCLUDES.include?(File.basename(patch))
        patch = relative(patch, @patch_directory)
        next if skip?(patch)
        result.warnings << "Patch #{File.basename(patch)} in VCS but not" \
                           ' listed in debian/series file.'
      end
      result
    end

    private

    def skip?(patch)
      series.patches.include?(patch) || ignore.patches.include?(patch)
    end

    def relative(path, path_base)
      Pathname.new(path).relative_path_from(Pathname.new(path_base)).to_s
    end

    def series
      @series ||= Debian::PatchSeries.new(@package_directory)
    end

    def ignore
      @ignore ||= Debian::PatchSeries.new(@package_directory, 'ignore')
    end
  end
end
