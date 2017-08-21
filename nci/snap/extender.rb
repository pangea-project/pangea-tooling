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

require 'rugged'
require 'tmpdir'
require 'yaml'

require_relative 'snapcraft_config'

module NCI
  module Snap
    module Extender
      module_function

      def snapname
        @snapname ||= ENV.fetch('APPNAME')
      end

      def extend(file)
        data = YAML.load_file(file)
        require 'pp'
        pp data
        data['parts'].each do |k, v|
          data['parts'][k] = SnapcraftConfig::Part.new(v)
        end

        # FIXME: this should be based on our overrides crap
        repo_url = "https://anongit.kde.org/#{snapname}"
        repo_branch = 'master'
        Dir.mktmpdir do |tmpdir|
          repo = Rugged::Repository.init_at(tmpdir)
          remote = repo.remotes.create_anonymous(repo_url)
          ref = remote.ls.find do |name:, **|
            name == "refs/heads/#{repo_branch}"
          end
          data['parts'][snapname].source = repo_url
          data['parts'][snapname].source_type = 'git'
          data['parts'][snapname].source_commit = ref.fetch(:oid)
          # FIXME: I want an @ here
          # https://bugs.launchpad.net/snapcraft/+bug/1712061
          data['version'] = "#{repo_branch.tr('/', '.')}+#{ref.fetch(:oid)}"
        end

        p Dir.pwd
        p file
        File.write('snapcraft.yaml', YAML.dump(data))
      end

      def run
        extend(ARGV.fetch(0, "#{Dir.pwd}/snapcraft.yaml"))
      end
    end
  end
end
