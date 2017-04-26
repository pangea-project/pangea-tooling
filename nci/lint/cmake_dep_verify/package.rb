# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require 'tty-command'

require_relative '../../../ci-tooling/lib/apt'
require_relative '../../../ci-tooling/lib/dpkg'

module CMakeDepVerify
  # Wrapper around a package we want to test.
  class Package
    Result = Struct.new(:success?, :out, :err)

    attr_reader :name
    attr_reader :version

    class << self
      def install_deps
        @run ||= (Apt.install(%w[cmake build-essential]) || raise)
      end

      attr_accessor :dry_run
    end

    def initialize(name, version)
      @name = name
      @version = version
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO
      @log.progname = "#{self.class}(#{name})"
      self.class.install_deps
    end

    def test
      failures = {}
      cmake_packages.each do |cmake_package|
        result = run(cmake_package)
        failures[cmake_package] = Result.new(result.success?, result.out,
                                             result.err)
      end
      failures
    end

    private

    def run(cmake_package)
      Dir.mktmpdir do |tmpdir|
        File.write("#{tmpdir}/CMakeLists.txt", <<-EOF)
cmake_minimum_required(VERSION 3.0)
find_package(#{cmake_package} REQUIRED)
EOF
        cmd = TTY::Command.new(dry_run: self.class.dry_run || false)
        cmd.run!('cmake', '.', chdir: tmpdir)
      end
    end

    def files
      Apt.install("#{name}=#{version}")
      Apt::Get.autoremove(args: '--purge')

      DPKG.list(name).select { |f| f.end_with?('Config.cmake') }
    end

    def cmake_packages
      @cmake_packages ||= begin
        x = files.collect { |f| File.basename(f, 'Config.cmake') }
        @log.info "CMake configs: #{x}"
        x
      end
    end
  end
end
