# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

# TODO change so if the ID of the app is also an ID in the provides then don't worry about it
# TODO review and add blacklist

# tests that the final appstream data doesn't have the same component more than
# once
class MGMTAppstreamComponentsDuplicatesJob < PipelineJob
  attr_reader :dist
  attr_reader :type

  def initialize(dist:, type:)
    super("mgmt_appstream-components_#{dist}_#{type}",
          template: 'mgmt_appstream_components_duplicates',
          cron: 'H H * * *')
    @dist = dist
    @type = type
  end
end
