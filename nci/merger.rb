#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/merger'

# FIXME: no test
# NCI merger.
class NCIMerger < Merger
  def run
    # The way this is pushed is that the first push called walks up the tree
    # and invokes push on the squenced branches. Susequent pushes will do the
    # same but essentially be no-op except for leafes which weren't part of the
    # first pushed sequence.
    unstable = sequence('Neon/release-lts').merge_into('Neon/release')
                                           .merge_into('Neon/stable')
                                           .merge_into('Neon/unstable')
    unstable.merge_into('Neon/mobile').push
    unstable.merge_into('Neon/pending-merge').push
  end
end

NCIMerger.new.run if $PROGRAM_NAME == __FILE__
