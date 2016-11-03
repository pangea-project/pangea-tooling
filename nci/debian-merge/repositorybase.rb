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

require 'git_clone_url'
require 'net/ssh'
require 'rugged'

module NCI
  module DebianMerge
    # A merging repo base.
    class RepositoryBase
      def initialize(rug)
        @rug = rug
      end

      def mangle_push_path!
        remote = @rug.remotes['origin']
        puts "pull url #{remote.url}"
        return unless remote.url.include?('anongit.neon.kde')
        pull_path = GitCloneUrl.parse(remote.url).path[1..-1]
        puts "mangle to neon@git.neon.kde.org:#{pull_path}"
        remote.push_url = "neon@git.neon.kde.org:#{pull_path}"
      end

      def credentials(url, username, types)
        raise unless types.include?(:ssh_key)
        config = Net::SSH::Config.for(GitCloneUrl.parse(url).host)
        default_key = "#{Dir.home}/.ssh/id_rsa"
        key = File.expand_path(config.fetch(:keys, [default_key])[0])
        Rugged::Credentials::SshKey.new(
          username: username,
          publickey: key + '.pub',
          privatekey: key,
          passphrase: ''
        )
      end
    end
  end
end
