#!/usr/bin/env ruby
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

require 'aptly'
require 'date'

require_relative 'lib/setup_repo'
require_relative '../lib/install_check'

TYPE = ENV.fetch('TYPE')
REPO_KEY = "#{TYPE}_#{ENV.fetch('DIST')}".freeze

NCI.setup_proxy!
NCI.add_repo_key!

Aptly.configure do |config|
  config.uri = URI::HTTPS.build(host: 'archive-api.neon.kde.org')
  # This is read-only.
end

proposed = AptlyRepository.new(Aptly::Repository.get(REPO_KEY), TYPE)
root = RootOnAptlyRepository.new([proposed])

checker = RootInstallCheck.new
checker.run(proposed, root)
