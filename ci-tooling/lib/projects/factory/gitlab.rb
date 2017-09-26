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

    # FIXME: same as in Neon except component is merged
    def split_entry(entry)
      parts = entry.split('/')
      name = parts[-1]
      component = parts[0..-2].join('_') || 'gitlab'
      [name, component]
    end

    def params(str)
      name, component = split_entry(str)
      default_params.merge(
        name: name,
        component: component,
        url_base: self.class.url_base
      )
    end

    class << self
      def ls(base)
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)
        # Gitlab sends over paginated replies, make sure we iterate till
        # no more results are being returned.

        base_id = ::Gitlab.group_search(base)[0].id
        repos = ::Gitlab.group_projects(base_id).auto_paginate
        @list_cache[base] = repos.collect(&:path).freeze
      end
    end
  end
end
