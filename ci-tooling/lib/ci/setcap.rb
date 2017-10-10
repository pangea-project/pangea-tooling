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

require 'drb/drb'

# setcap client component. This talks to the builder over the druby IPC giving
# it our ARGV to assert on. Essentially this allows the builder to terminate
# if we attempt to run an unexpected setcap call (i.e. not whitelisted/not in
# postinst).

PACKAGE_BUILDER_DRB_URI = ENV.fetch('PACKAGE_BUILDER_DRB_URI')

DRb.start_service

server = DRbObject.new_with_uri(PACKAGE_BUILDER_DRB_URI)
server.check_expected(ARGV)

# Not wanted nor needed as of right now. The assumption is that we handle the
# caps in postinst exclusively, so calling the real setcap is useless and wrong.
# exec("#{__dir__}/setcap.orig", *ARGV)
