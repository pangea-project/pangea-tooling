# frozen_string_literal: true
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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

require_relative '../job'

# Base class for snapshotting. Don't use directly.
class MGMTSnapshotBase < JenkinsJob
  attr_reader :target
  attr_reader :origin
  attr_reader :appstream
  attr_reader :dist

  def initialize(origin:, target:, appstream:, dist:)
    super("mgmt_snapshot_#{dist}_#{target}", 'mgmt_snapshot.xml.erb')
    @origin = origin
    @target = target
    @appstream = appstream
    @dist = dist
  end
end

# snapshots release repos
class MGMTSnapshotUser < MGMTSnapshotBase
  def initialize(dist:)
    super(dist: dist,
          origin: 'release', target: 'user',
          appstream: "_#{dist}")
  end
end

# snapshots release-lts repos
class MGMTSnapshotUserLTS < MGMTSnapshotBase
  def initialize(dist:)
    super(dist: dist,
          origin: 'release-lts', target: 'user-lts',
          appstream: "_#{dist}-lts")
  end
end
