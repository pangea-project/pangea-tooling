# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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

require 'tmpdir'
require 'tty/command'

require_relative '../../ci-tooling/lib/dpkg'

# A fake package
class FakePackage
  attr_reader :name
  attr_reader :version

  # Logic wrapper to force desired run behavior. Which is to say not verbose
  # becuase FakePackage may get called a lot.
  class OutputOnErrorCommand < TTY::Command
    def initialize(*args)
      super(*args, uuid: false, printer: :progress)
    end

    def run(*args)
      super(*args, only_output_on_error: true)
    end
  end
  private_constant :OutputOnErrorCommand

  class << self
    def cmd
      @cmd ||= OutputOnErrorCommand.new
    end
  end

  def initialize(name, version = '999:999')
    @name = name
    @version = version
  end

  def install
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        build
        DPKG.dpkg(['-i', deb]) || raise
      end
    end
  end

  private

  def cmd
    self.class.cmd
  end

  def deb
    "#{name}.deb"
  end

  def build
    FileUtils.mkpath("#{name}/DEBIAN")
    File.write("#{name}/DEBIAN/control", <<-CONTROL.gsub(/^\s+/, ''))
      Package: #{name}
      Version: #{version}
      Architecture: all
      Maintainer: Harald Sitter <sitter@kde.org>
      Description: fake override package for CI use
    CONTROL
    cmd.run('dpkg-deb', '-b', '-Znone', '-Snone', name, deb)
  end
end
