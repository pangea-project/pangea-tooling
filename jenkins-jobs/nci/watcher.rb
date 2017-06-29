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

require_relative '../job'
require_relative '../../ci-tooling/lib/nci'

# Watches for releases.
class WatcherJob < JenkinsJob
  attr_reader :scm_readable
  attr_reader :scm_writable
  attr_reader :nci
  attr_reader :periodic_build

  def initialize(project)
    super("watcher_release_#{project.component}_#{project.name}",
          'watcher.xml.erb')
    @scm_readable = Marshal.load(Marshal.dump(project.packaging_scm))
    @scm_writable = Marshal.load(Marshal.dump(project.packaging_scm))
    # FIXME: brrr the need for deep copy alone should ring alarm bells
    @scm_writable.url.gsub!('git://anongit.neon.kde.org/',
                            'neon@git.neon.kde.org:')
    # Don't touch release-lts for Plasma jobs
    if project.component == 'plasma'
      @scm_writable.branch.replace('Neon/release')
    else
      @scm_writable.branch.replace('Neon/release-lts')
    end
    @nci = NCI
    periodic_watch_components = ['kde-extras', 'kde-req', 'kde-std', 'neon-packaging', 'forks']
    if periodic_watch_components.include?(project.component)
      @periodic_build = 'H H * * *'
    else
      @periodic_build = ''
    end
  end
end
