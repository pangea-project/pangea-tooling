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

require 'json'

module ASGEN
  # Helper with a default to_json method serializing all members into a hash.
  module MemberSerialize
    def to_json(options = nil)
      instance_variables.collect do |x|
        value = instance_variable_get(x)
        next nil unless value
        [x.to_s.tr('@', ''), value]
      end.compact.to_h.to_json(options)
    end
  end

  # An asgen suite.
  class Suite
    include MemberSerialize

    attr_accessor :name
    attr_accessor :sections
    attr_accessor :architectures

    attr_accessor :dataPriority
    attr_accessor :baseSuite
    attr_accessor :useIconTheme

    def initialize(name, sections = [], architectures = [])
      @name = name
      @sections = sections
      @architectures = architectures
    end
  end

  # Configuration main class.
  class Conf
    include MemberSerialize

    attr_accessor :ProjectName
    attr_accessor :ArchiveRoot
    attr_accessor :MediaBaseUrl
    attr_accessor :HtmlBaseUrl
    attr_accessor :Backend
    attr_accessor :Features
    attr_accessor :Suites
    attr_accessor :CAInfo

    def initialize(name)
      @ProjectName = name
      @Features = {}
      @Suites = []
    end

    def write(file)
      File.write(file, JSON.generate(self))
    end
  end
end
