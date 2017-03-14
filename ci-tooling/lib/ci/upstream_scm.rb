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

require 'erb'
require 'json'
require 'yaml'

require_relative 'pattern'
require_relative 'scm'

module CI
  # Construct an upstream scm instance and fold in overrides set via
  # meta/upstream_scm.json.
  class UpstreamSCM < SCM
    # Constructs an upstream SCM description from a packaging SCM description.
    #
    # Upstream SCM settings default to sane KDE settings and can be overridden
    # via data/overrides/*.yml. The override file supports pattern matching
    # according to File.fnmatch and ERB templating using a Project as binding
    # context.
    #
    # @param packaging_repo [String] git URL of the packaging repo
    # @param packaging_branch [String] branch of the packaging repo
    # @param working_directory [String] local directory path of directory
    #   containing debian/ (this is only used for repo-specific overrides)
    def initialize(packaging_repo, packaging_branch,
                   working_directory = Dir.pwd)
      @packaging_repo = packaging_repo
      @packaging_branch = packaging_branch
      @name = File.basename(packaging_repo)
      @directory = working_directory

      super('git', "git://anongit.kde.org/#{@name.chomp('-qt4')}", 'master')
    end
  end
end

require_relative '../deprecate'
# Deprecated. Don't use.
class UpstreamSCM < CI::UpstreamSCM
  extend Deprecate
  deprecate :initialize, CI::UpstreamSCM, 2015, 12
end
