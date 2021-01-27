# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'

module NCI
  # Lists packages in a directory by dpkg-deb inspecting all *.deb
  # files.
  class DirPackageLister
    Package = Struct.new(:name, :version)

    def initialize(dir, filter_select: nil)
      @dir = File.expand_path(dir)
      @filter_select = filter_select
    end

    def packages
      @packages ||= begin
        cmd = TTY::Command.new(printer: :null)
        packages = Dir.glob("#{@dir}/*.deb").collect do |debfile|
          out, _err = cmd.run('dpkg-deb',
                              "--showformat=${Package}\t${Version}\n",
                              '--show', debfile)
          out.split($/).collect { |line| Package.new(*line.split("\t")) }
        end.flatten
        return packages unless @filter_select

        packages.select { |x| @filter_select.include?(x.name) }
      end
    end
  end
end
