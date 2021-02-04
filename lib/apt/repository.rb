# frozen_string_literal: true
#
# Copyright (C) 2014-2018 Harald Sitter <sitter@kde.org>
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

# Technically this requires apt.rb but that'd be circular, so we'll only
# require it in when a repo is constructed. This makes it a lazy require.

module Apt
  # Represents a repository
  class Repository
    def initialize(name)
      require_relative '../apt.rb'
      @name = name
      self.class.send(:install_add_apt_repository)
      @default_args = []
      if self.class.send(:disable_auto_update?)
        # Since Ubuntu 18.04 the default behavior is to automatically run an
        # update which will fail without retrying if there was a network error.
        # We largely have retry systems in place and generally want more control
        # over when updates happen, so alway disable the auto-update
        @default_args << '--no-update'
      end
    end

    # (see #add)
    def self.add(name)
      new(name).add
    end

    # Add Repository to sources.list
    def add
      args = [] + @default_args
      args << '-y'
      args << @name
      system('add-apt-repository', *args)
    end

    # (see #remove)
    def self.remove(name)
      new(name).remove
    end

    # Remove Repository from sources.list
    def remove
      args = [] + @default_args
      args << '-y'
      args << '-r'
      args << @name
      system('add-apt-repository', *args)
    end

    class << self
      private

      def install_add_apt_repository
        return if add_apt_repository_installed?
        return unless Apt.install('software-properties-common')
        @add_apt_repository_installed = true
      end

      def add_apt_repository_installed?
        return @add_apt_repository_installed if ENV['PANGEA_UNDER_TEST']
        @add_apt_repository_installed ||= marker_exist?
      end

      # Own method so we can mocha this check! Do not merge into other method.
      def marker_exist?
        File.exist?('/var/lib/dpkg/info/software-properties-common.list')
      end

      def disable_auto_update?
        @disable_auto_update ||=
          `add-apt-repository --help`.include?('--no-update')
      end

      def reset
        if defined?(@add_apt_repository_installed)
          remove_instance_variable(:@add_apt_repository_installed)
        end
        return unless defined?(@disable_auto_update)
        remove_instance_variable(:@disable_auto_update)
      end
    end
  end
end
