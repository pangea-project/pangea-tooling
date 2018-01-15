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

require_relative '../job'

# Base class for all prunes
class MGMTJenkinsBasePruneJob < JenkinsJob
  attr_accessor :max_age
  attr_accessor :min_count
  attr_accessor :paths

  def initialize(name:, paths:, max_age:, min_count:)
    super("mgmt_jenkins_prune_#{name}", 'mgmt_jenkins_prune.xml.erb')
    self.max_age = max_age
    self.min_count = min_count
    self.paths = paths
  end
end

# Prunes parameter-files
class MGMTJenkinsPruneParameterListJob < MGMTJenkinsBasePruneJob
  def initialize
    super(name: 'parameter-files', paths: %w[parameter-files fileParameters],
          max_age: -1, min_count: 1)
  end
end
