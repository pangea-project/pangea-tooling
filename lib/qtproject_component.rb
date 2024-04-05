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
# downloads and makes available as arrays lists of KDE projects which
# are part of Plasma, Applications and Frameworks

require 'gitlab'
require 'json'

Gitlab.endpoint = 'https://invent.kde.org/api/v4'
Gitlab.private_token = ''

neon_projects = Gitlab.group_projects(6006,).auto_paginate.to_json

JSON.parse(neon_projects)

p JSON.pretty_generate(neon_projects)
#p neon_projects

class QTProjectsComponent
  class << self
    @@projects_to_jobs = {}

    def qt5
      qt5 ||= to_names(projects('qt'))
    end

    def qt5_jobs
      @qt5_packages ||= to_jobs(qt5)
    end

    def qt6
      qt6 ||= to_names(projects('qt6'))
      @qt6_packages ||= to_jobs(qt6)
    end

    def to_jobs(projects)
      projects.collect { |x| @@projects_to_jobs[x]? @@projects_to_jobs[x] : x }
    end

    def to_names(projects)
      projects.collect { |project| project.split('/')[-1] }
    end

    def projects(filter)
      url = "https://invent.kde.org/api/v4#{filter}"
      response = HTTParty.get(url)
      response.parsed_response
    end
  end
end
