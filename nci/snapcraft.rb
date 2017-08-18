#!/usr/bin/env ruby
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

require 'tty/command'

require_relative '../ci-tooling/lib/apt'
require_relative '../ci-tooling/nci/lib/setup_repo'

if $PROGRAM_NAME == __FILE__
  NCI.setup_repo!
  NCI.setup_env!
  # KDoctools is rubbish and lets meinproc resolve asset paths through
  #  QStandardPaths *AT BUILD TIME*.
  ENV['XDG_DATA_DIRS'] = "#{Dir.pwd}/stage/usr/local/share:#{Dir.pwd}/stage/usr/share:/usr/local/share:/usr/share"
  Apt.install('snapcraft')
  TTY::Command.new(uuid: false).run('snapcraft --debug')
end
