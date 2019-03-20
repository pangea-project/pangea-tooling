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

    DEFAULT_URL_BASE = 'https://github.com'
    DEFAULT_PRIVATE_URL_BASE = 'ssh://git@github.com:'

    # FIXME: same as in neon
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.private_url_base
      @private_url_base ||= DEFAULT_PRIVATE_URL_BASE
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

      component_repos = self.class.repo_cache.fetch(component)
      repo = component_repos.find { |x| x.name == name }
      raise unless repo
      url_base = "#{self.class.url_base}/"
      url_base = self.class.private_url_base if repo.private

      default_params.merge(
        name: name,
        component: component,
        url_base: url_base
      )
    end

    class << self
      def repo_cache
        @repo_cache ||= {}
      end

      def repo_names_for_base(base)
        repo_cache[base]&.collect(&:name)&.freeze
      end

      def load_repos_for_base(base)
        repo_cache[base] ||= begin
          Octokit.auto_paginate = true
          client = Octokit::Client.new
          begin
            client.login
            client.org_repos(base)
          rescue Net::OpenTimeout, Faraday::SSLError, Faraday::ConnectionFailed
            retry
          end
        end
      end

      def ls(base)
        load_repos_for_base(base)
        repo_cache[base]&.collect(&:name)&.freeze
      end
    end
  end
end
