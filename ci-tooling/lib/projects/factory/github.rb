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

require 'octokit'

require_relative 'base'
require_relative 'common'

class ProjectsFactory
  # Debian specific project factory.
  class GitHub < Base
    include ProjectsFactoryCommon
    DEFAULT_URL_BASE = 'https://github.com'.freeze

    # FIXME: same as in neon
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'github.com'
    end

    private

    # FIXME: same as in Neon except component is merged
    def split_entry(entry)
      parts = entry.split('/')
      name = parts[-1]
      component = parts[0..-2].join('_') || 'github'
      [name, component]
    end

    def params(str)
      name, component = split_entry(str)
      default_params.merge(
        name: name,
        component: component,
        url_base: "#{self.class.url_base}/"
      )
    end

    class << self
      def ls(base)
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)

        Octokit.auto_paginate = true
        client = Octokit::Client.new
        begin
            client.login
            repos = client.org_repos(base)
        rescue Net::OpenTimeout
            retry
        end
        @list_cache[base] = repos.collect(&:name).freeze
      end
    end
  end
end
