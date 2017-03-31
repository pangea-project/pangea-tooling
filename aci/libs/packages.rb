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
require_relative 'frameworks'
require_relative '../../ci-tooling/lib/apt'
require 'fileutils'
require 'yaml'
require 'set'
require 'open-uri'

# Module for installing distribution packages and retrieval of pre packaged appimage tools
module Packages
  def self.install_packages(args = {})
    kde = args[:kde]
    projectpackages = args[:projectpackages]
    packagelist = Set.new
    packagelist.merge(projectpackages) if projectpackages
    packagelist.merge(Frameworks.generatekf5_packages) if kde
    #  packagelist = packagelist.to_a.join(' ')
    Apt.install(%w(packagelist.to_join(" "))) || raise if packagelist
    $?.exitstatus
  end


  def self.retrieve_tools(args= {})
    url = args[:url]
    file = args[:file]
    download = open(url)
    IO.copy_stream(download, file)
  end
end
