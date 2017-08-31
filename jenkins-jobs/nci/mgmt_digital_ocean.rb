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
require_relative 'pipelinejob'

# Manages digital ocean base snapshot from which we build cloud instances
class MGMTDigitalOcean < JenkinsJob
  def initialize
    super('mgmt_digital-ocean', 'mgmt_digital_ocean.xml.erb')
  end
end

# Manages digital ocean safety net to delete dangling droplets.
class MGMTDigitalOceanDangler < PipelineJob
  def initialize
    super('mgmt_digital-ocean_dangler', cron: 'H H/3 * * *')
  end
end
