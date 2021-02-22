# frozen_string_literal: true
#
# Copyright (C) 2016 Rohan Garg <rohan@garg.io>
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

require 'bundler/setup'
require 'gitlab'

require_relative 'base'
require_relative 'common'

class ProjectsFactory
  # Debian specific project factory.
  class Gitlab < Base
    include ProjectsFactoryCommon
    DEFAULT_URL_BASE = 'https://gitlab.com'

    # FIXME: same as in neon
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'gitlab.com'
    end

    private

    def split_entry(entry)
      parts = entry.split('/')
      name = parts.pop
      component = parts.pop
      group = parts.join('/')
      [name, component, group]
    end

    def params(str)
      name, component, group = split_entry(str)
      default_params.merge(
        name: name,
        component: component,
        url_base: "#{self.class.url_base}/#{group}"
      )
    end

    class << self
      def ls(base)
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)

        base_id = ::Gitlab.group_search(base)[0].id
        # gitlab API is bit meh, when you ask path, it just returns parent subgroup
        # so we, ask for path_with_namespace and strip the top-most group name
        repos = list_repos(base_id).collect { |x| x.split('/', 2)[-1] }
        @list_cache[base] = repos.freeze
      end

      def list_repos(group_id)
        # Gitlab sends over paginated replies, make sure we iterate till
        # no more results are being returned.
        repos = ::Gitlab.group_projects(group_id)
                         .auto_paginate
                         .collect(&:path_with_namespace)
        repos += ::Gitlab.group_subgroups(group_id).auto_paginate.collect do |subgroup|
          list_repos(subgroup.id)
        end
        repos.flatten
      end
    end
  end
end
