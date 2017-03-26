#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
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

require_relative '../libs/sources'
require_relative '../libs/packages'
require_relative '../libs/metadata'
require 'yaml'

exit_status = 'Expected 0 exit Status'

describe 'install_packages' do
  it 'Installs distribution packages' do
    p Metadata::BUILDKF5
    p Metadata::METADATA
    p Metadata::FRAMEWORKS
    expect(
      Packages.install_packages(
        kde: Metadata::BUILDKF5
      )
    ).to be(0), exit_status
  end
end
