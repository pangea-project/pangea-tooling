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

require 'open-uri'

module Apt
  # Apt key management using apt-key binary
  class Key
    class << self
      def method_missing(name, *caller_args)
        system('apt-key', name.to_s.tr('_', '-'), *caller_args)
      end

      # Add a GPG key to APT.
      # @param str [String] can be a file path, or an http/https/ftp URI or
      #   a fingerprint/keyid or a fucking file, if you pass a fucking file you
      #   are an idiot.
      def add(str)
        # If the thing passes for an URI with host and path we use it as url
        # otherwise as fingerprint. file:// uris would not qualify, we do not
        # presently have a use case for them though.
        if url?(str)
          add_url(str)
        else
          add_fingerprint(str)
        end
      end

      def add_url(url)
        data = open(url).read
        IO.popen(['apt-key', 'add', '-'], 'w') do |io|
          io.puts(data)
          io.close_write
        end
        $?.success?
      end

      def add_fingerprint(id_or_fingerprint)
        system('apt-key', 'adv',
               '--keyserver', 'keyserver.ubuntu.com',
               '--recv', id_or_fingerprint)
      end

      private

      def url?(str)
        uri = URI.parse(str)
        remote?(uri) || local?(uri)
      rescue
        false
      end

      def remote?(uri)
        # If a URI has a host and a path we'll assume it to be a path
        !uri.host.to_s.empty? && !uri.path.to_s.empty?
      end

      def local?(uri)
        # Has no host but a path and that path is a local file?
        # Must be a local uri.
        # NB: fingerpints or keyids are incredibly unlikely to match this, but
        #   they could if one has particularly random file names in PWD.
        uri.host.to_s.empty? && (!uri.path.to_s.empty? && File.exist?(uri.path))
      end
    end
  end
end
