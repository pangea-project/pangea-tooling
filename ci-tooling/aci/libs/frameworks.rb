#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
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
require_relative 'metadata'
require 'fileutils'
require 'yaml'
require 'set'

# Module for installing distribution packages
module Frameworks
  KF5 = YAML.load_file('../data/kf5.yaml')

  def self.generatekf5_packages
    frameworks = Metadata::FRAMEWORKS
    kf5_packages = Set.new
    frameworks.each do |f|
      p f
      dep_list = KF5[f].select { |k| k['distro_packages'] }
      p dep_list
      kf5_packages.merge(dep_list) if dep_list
    end
    kf5_packages
  end

  def self.generatekf5_buildorder
    frameworks = Metadata::FRAMEWORKS
    buildorder = Set.new
    frameworks.each do |f|
      p f
      dep_list = KF5[f]
      kf5list = dep_list['kf5_deps']
      p kf5list
      buildorder.merge(kf5list) if kf5list
      buildorder.delete(f)
      builderorder.add(f)
      p buildorder
    end
    buildorder
  end
end
