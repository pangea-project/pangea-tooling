require 'date'

require_relative '../os'
require_relative '../debian/changelog'

module CI
  # Wraps a debian changelog to construct a build specific version based on the
  # version used in the changelog.
  class BuildVersion
    TIME_FORMAT = '%Y%m%d.%H%M'

    # Version (including epoch)
    attr_reader :base
    # Version (excluding epoch)
    attr_reader :tar
    # Version include epoch AND possibly a revision
    attr_reader :full

    def initialize(changelog)
      @changelog = changelog
      @suffix = format('+git%s+%s', time, version_id)
      @tar = "#{clean_base}#{@suffix}"
      @base = "#{changelog.version(Changelog::EPOCH)}#{clean_base}#{@suffix}"
      @full = "#{base}-0"
    end

    # Version (including epoch AND possibly a revision)
    def to_s
      full
    end

    private

    # Helper to get the time string for use in the version
    def time
      DateTime.now.strftime(TIME_FORMAT)
    end

    # Removes non digits from base version string.
    # This is to get rid of pesky alphabetic suffixes such as 5.2.2a which are
    # lower than 5.2.2+git (which we might have used previously), as + reigns
    # supreme. Always.
    def clean_base
      base = @changelog.version(Changelog::BASE)
      base = base.chop until base.empty? || base[-1].match(/[\d\.]/)
      return base unless base.empty?
      fail 'Failed to find numeric version in the changelog version:' \
           " #{@changelog.version(Changelog::BASE)}"
    end

    def version_id
      if OS.to_h.key?(:VERSION_ID)
        id = OS::VERSION_ID
        return OS::VERSION_ID unless id.nil? || id.empty?
      end

      return '9' if OS::ID == 'debian'
      fail 'VERSION_ID not defined!'
    end
  end
end
