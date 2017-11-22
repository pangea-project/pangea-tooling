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

module Apt
  # man apt_preferences. Manages preference files. Does not manage the content
  # (yet) but instead leaves it to the user to give a config blob which we'll
  # write to a suitable file.
  class Preference
    DEFAULT_CONFIG_DIR = '/etc/apt/preferences.d/'

    class << self
      def config_dir
        @config_dir ||= DEFAULT_CONFIG_DIR
      end
      attr_writer :config_dir
    end

    def initialize(name, content: nil)
      @name = name
      @content = content
    end

    def path
      "#{self.class.config_dir}/#{@name}"
    end

    def write
      File.write(path, @content)
    end

    def delete
      File.delete(path)
    end
  end
end
