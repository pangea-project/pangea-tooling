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
require 'erb'
require 'fileutils'
require 'yaml'

class Recipe
  attr_accessor :name
  attr_accessor :arch
  attr_accessor :desktop
  attr_accessor :icon
  attr_accessor :iconpath
  attr_accessor :install_path
  attr_accessor :packages
  attr_accessor :dep_path
  attr_accessor :repo
  attr_accessor :type
  attr_accessor :archives
  attr_accessor :md5sum
  attr_accessor :version
  attr_accessor :app_dir
  attr_accessor :configure_options
  attr_accessor :binary

  def initialize(args = {})
    Dir.chdir('/')
    self.name = args[:name]
    self.binary = args[:binary]
    self.arch = `arch`
    self.install_path = '/app/usr'
  end

  def clean_workspace(args = {})
    self.name = args[:name]
    return if Dir['/app/'].empty?
    FileUtils.rm_rf("/app/.", secure: true)
    return if Dir['/appimage/'].empty?
    FileUtils.rm_rf("/appimage/.", secure: true)
    return if Dir["/in/#{name}"].empty?
    FileUtils.rm_rf("/in/#{name}/#{name}-builddir", secure: true)
  end

  def install_packages(args = {})
    self.packages = args[:packages].to_s.gsub(/\,|\[|\]/, '')
    system('apt-get update && apt-get -y upgrade')
    system("DEBIAN_FRONTEND=noninteractive apt-get -y install git wget #{packages}")
    $?.exitstatus
  end

  def render
    ERB.new(File.read('/in/Recipe.erb')).result(binding)
  end

  def generate_appimage(args = {})
    system('/bin/bash -xe /in/Recipe')
    $?.exitstatus
  end


end
