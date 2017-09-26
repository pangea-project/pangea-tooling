# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

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
      @suffix = format('+p%s+git%s', version_id, time)
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
      raise 'Failed to find numeric version in the changelog version:' \
           " #{@changelog.version(Changelog::BASE)}"
    end

    def version_id
      if OS.to_h.key?(:VERSION_ID)
        id = OS::VERSION_ID
        return OS::VERSION_ID unless id.nil? || id.empty?
      end

      return '9' if OS::ID == 'debian'
      raise 'VERSION_ID not defined!'
    end
  end
end
