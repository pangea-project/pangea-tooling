# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require_relative '../debian/version'

module CI
  # Helper to enforce that the Debian epoch version did not change in between
  # builds without approval from someone.
  # The enforcer loads previous version information from a record file
  # and then can be asked to #{validate} new versions. Failing validation
  # raises UnauthorizedChangeError exceptions!
  # Validation fails iff the epoch between the recorded and validation version
  # changed... At all. The only way to bypass the enforcer is to have no
  # last_version in the working directory.
  class VersionEnforcer
    class UnauthorizedChangeError < StandardError; end

    RECORDFILE = 'last_version'

    attr_reader :old_version

    def initialize
      # TODO: couldn't this use the @source instances?
      return unless File.exist?(RECORDFILE)
      @old_version = File.read(RECORDFILE)
      @old_version = Debian::Version.new(@old_version)
    end

    def validate(new_version)
      return unless @old_version
      new_version = Debian::Version.new(new_version)
      validate_epochs(@old_version.epoch, new_version.epoch)
      # TODO: validate that the new version is strictly greater
    end

    def record!(new_version)
      File.write(RECORDFILE, new_version)
    end

    private

    def validate_epochs(old_epoch, new_epoch)
      return if old_epoch == new_epoch
      raise UnauthorizedChangeError, "#{old_epoch} -> #{new_epoch}"
    end
  end
end
