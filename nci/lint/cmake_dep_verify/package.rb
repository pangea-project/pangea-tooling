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

require_relative '../../../ci-tooling/lib/apt'
require_relative '../../../ci-tooling/lib/dpkg'

module CMakeDepVerify
  # Wrapper around a package we want to test.
  class Package
    attr_reader :name
    attr_reader :version

    class << self
      def install_deps
        @run ||= (Apt.install(%w[cmake build-essential]) || raise)
      end
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
      failed = [] # FIXME: this should be a hash name=>stdout/stderr
      cmake_packages.each do |cmake_package|
        Dir.mktmpdir do |tmpdir|
          File.write("#{tmpdir}/CMakeLists.txt", <<-EOF)
cmake_minimum_required(VERSION 3.0)
find_package(#{cmake_package} REQUIRED)
EOF
          next if run_cmake_in(tmpdir)
          failed << cmake_package
        end
      end
      failed
    end

    private

    def run_cmake_in(dir)
      system('cmake', '.', chdir: dir)
    end

    def files
      # FIXME: need to fail otherwise, the results will be skewed?
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
