# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'
require_relative '../../lib/retry'

# Neon CI specific helpers.
module NCI
  module_function

  def setup_repo_key!
    # FIXME: this needs to be in the apt module!
    IO.popen(['apt-key', 'add', '-'], 'w') do |io|
      io.puts open('http://archive.neon.kde.org.uk/public.key').read
      io.close_write
    end
  end

  def setup_repo!
    debline = format('deb http://archive.neon.kde.org.uk/unstable %s main',
                     LSB::DISTRIB_CODENAME)
    raise 'adding repo failed' unless Apt::Repository.add(debline)
    setup_repo_key!
    raise 'Failed to import key' unless $? == 0
    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }
    raise 'failed to install deps' unless Apt.install(%w(pkg-kde-tools))
  end
end
