# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../publisher'

# Neon extension to publisher
class NeonPublisherJob < PublisherJob
  attr_reader :frameworks

  def initialize(basename, type:, distribution:, dependees:,
                 component:, upload_map:, architectures:, frameworks:)
    super(basename, type: type, distribution: distribution, dependees: dependees, component: component, upload_map: upload_map, architectures: architectures)
    @frameworks = frameworks
  end

  # When chain-publishing lock all aptly resources. Chain publishing can
  # cause a fairly long lock on the database with a much greater risk of timeout
  # by locking all resources instead of only one we'll make sure no other
  # jobs can time out while we are publishing.
  def aptly_resources
    repo_names.size > 1 ? 0 : 1
  end

  # @return Array<String> array of repo identifiers suitable for pangea_dput
  def repo_names
    repos = ["#{type}_#{distribution}"]
    return repos unless type == 'unstable'

    # This has no stable version, the unstable version is supplying stable.
    # By pushing it forward we save on build time and noise jobs.
    repos << "stable_#{distribution}" if push_to_stable?

    # Qt things take forever to build, save on time and noise by forward
    # publishing them everywhere.
    #
    # NOTE: Not in release-lts since I think that is frozen, I am only
    #   guessing though. Jon has trouble writing comments.  - sitter
    repos += ["stable_#{distribution}", "release_#{distribution}"] if qtish?

    repos
  end

  private

  def push_to_stable?
    frameworks.any? { |x| basename.include?(x) }
      %w[pkg-kde-tools phonon].any? { |x| basename.include?(x) }
  end

  def qtish?
    component == 'qt' || basename.end_with?('pyqt5', 'sip4')
  end
end
