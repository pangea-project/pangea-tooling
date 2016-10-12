# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
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

require_relative '../dci/lib/setup_repo'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class DCISetupRepoTest < TestCase
  def setup
    # Reset caching.
    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['DIST'] = 'stable'
  end

  def teardown
    WebMock.allow_net_connect!
    ENV['DIST'] = nil
  end

  def test_setup_repos
    release = `lsb_release -sc`.strip
    system_calls = [
      ['dpkg --add-architecture i386'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'lsb-release'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'software-properties-common'],
      ['add-apt-repository', '-y', "deb http://deb.debian.org/debian #{release}-backports main"],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', "devscripts/#{release}-backports", "pbuilder/#{release}-backports", "dh-autoreconf/#{release}-backports"],
      ['add-apt-repository', '-y', 'deb http://dci.ds9.pub:8080/frameworks stable main'],
      ['add-apt-repository', '-y', 'deb http://dci.ds9.pub:8080/plasma stable main'],
      ['add-apt-repository', '-y', 'deb http://dci.ds9.pub:8080/kde-applications stable main'],
      ['add-apt-repository', '-y', 'deb http://dci.ds9.pub:8080/backports stable main'],
      ['add-apt-repository', '-y', 'deb http://dci.ds9.pub:8080/qt5 stable main'],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'dist-upgrade'],
    ]


    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    key_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(key_catcher)
      .returns(true)

    DCI.setup_repo!
  end
end
