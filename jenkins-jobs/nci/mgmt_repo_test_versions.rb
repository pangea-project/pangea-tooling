# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative 'pipelinejob'

# Tests that for all our debs the apt cache shows us offering the version we
# expect (not a different one and not one from ubuntu)
class MGMTRepoTestVersionsJob < PipelineJob
  attr_reader :distribution
  attr_reader :type

  def initialize(distribution:, type:)
    super("mgmt_repo_test_versions_#{type}_#{distribution}",
          template: 'mgmt_repo_test_versions',
          cron: 'H H(21-23) * * *',
          with_push_trigger: false)
    # Runs once a day after 21 UTC
    # Disables with_push_trigger because it clones its own tooling, so it'd
    # erronously trigger on tooling changes.
    @distribution = distribution
    @type = type
  end
end

# Special upgrade variants, performs the same check between current and
# future series to ensure the new series' versions (both ours and ubuntus)
# are greater than our old series'.
class MGMTRepoTestVersionsUpgradeJob < PipelineJob
  attr_reader :distribution
  attr_reader :type

  # distribution in this case is the series the test should be run as.
  # the "old" series is determined from the NCI metadata
  def initialize(distribution:, type:)
    super("mgmt_repo_test_versions_upgrades_#{type}_#{distribution}",
          template: 'mgmt_repo_test_versions_upgrade',
          cron: 'H H(21-23) * * *',
          with_push_trigger: false)
    # Runs once a day after 21 UTC
    # Disables with_push_trigger because it clones its own tooling, so it'd
    # erronously trigger on tooling changes.
    @distribution = distribution
    @type = type
  end
end
