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
require 'jenkins_junit_builder'

require_relative '../../../lib/qml_dependency_verifier'
require_relative '../../../lib/repo_abstraction'

module Lint
  # A QML linter
  class QML
    def initialize(type, dist)
      @type = type
      @repo = "#{type}_#{dist}"
      @missing_modules = []
      prepare
    end

    def lint
      return unless @has_qml
      aptly_repo = Aptly::Repository.get(@repo)
      qml_repo = ChangesSourceFilterAptlyRepository.new(aptly_repo, @type)
      verifier = QMLDependencyVerifier.new(qml_repo)
      @missing_modules = verifier.missing_modules
      return if @missing_modules.empty?
      write
    end

    private

    # A junit case representing a package with missing qml files
    class PackageCase < JenkinsJunitBuilder::Case
      def initialize(package, modules)
        super()
        self.name = package
        self.time = 0
        self.classname = name
        # We only get missing modules out of the linter
        self.result = JenkinsJunitBuilder::Case::RESULT_ERROR
        system_out.message = modules.join($/)
      end
    end

    def prepare
      dsc = Dir.glob('*.dsc')[0] || raise
      # Internally qml_dep_verify/package expects things to be in packaging/
      system('dpkg-source', '-x', dsc, 'packaging') || raise
      @has_qml = !Dir.glob('packaging/**/*.qml').empty?
    end

    def to_xml
      suite = JenkinsJunitBuilder::Suite.new
      suite.name = 'QMLDependencies'
      suite.package = 'qml'
      @missing_modules.each do |package, modules|
        suite.add_case(PackageCase.new(package, modules))
      end
      suite.build_report
    end

    def write
      File.write('junit.xml', to_xml)
    end
  end
end
