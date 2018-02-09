#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'tty/command'

INFO_DIR = '/var/lib/dpkg/info/'

# Finds dangling configs of a package
class DanglingConfigCheck
  def initialize(list_file)
    @list_file = list_file
    @pkg = File.basename(list_file, '.list')
    @conffiles_file = File.join(INFO_DIR, "#{@pkg}.conffiles")
  end

  def danglers
    danglers = []

    each_list do |line|
      next unless line.start_with?('/etc/')
      next unless File.file?(line) && !File.symlink?(line)
      danglers << line
    end

    each_conffiles { |line| danglers.delete(line) }

    # Maintainer check is fairly expensive, if we have no danglers we can
    # abort here already, the maintainer check does nothing for us.
    # If we are not maintainer we'll ignore all danglers.
    return danglers if danglers.empty?
    kde_maintainer? ? danglers : []
  end

  private

  def each_list
    return unless File.exist?(@list_file)
    File.foreach(@list_file) do |line|
      yield line.strip
    end
  end

  def each_conffiles
    return unless File.exist?(@conffiles_file)
    File.foreach(@conffiles_file).each do |line|
      yield line.strip
    end
  end

  def kde_maintainer?
    @kde_maintainer ||= begin
      return false if %w[base-files].include?(@pkg)
      out = `dpkg-query -W -f='${Maintainer}\n' #{@pkg}` || ''
      out.split("\n").any? do |line|
        line.include?('kde')
      end
    end
  end
end

error = false
Dir.glob(File.join(INFO_DIR, '*.list')) do |list|
  danglers = DanglingConfigCheck.new(list).danglers
  next if danglers.empty?
  warn <<-ERROR
--------------------------------------------------------------------------------
Dangling configuration files detected. The package list
#{list}
contains the following configuration files, they are however not tracked as
configuration files anymore (i.e. they were dropped from the packaging but
kept around on disk). Disappearing configuration files need to be properly
removed via *.maintscript files in the packaging!
#{danglers.inspect}

  ERROR
  error = true
end
raise if error
