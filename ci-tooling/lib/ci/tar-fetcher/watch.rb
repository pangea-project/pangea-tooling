# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require 'open-uri'
require 'tmpdir'

require_relative '../tarball'

module CI
  # Fetch tarballs via uscan using debian/watch.
  class WatchTarFetcher
    def initialize(watchfile, mangle_download = false)
      unless File.basename(watchfile) == 'watch'
        raise "path not a watch file #{watchfile}"
      end
      debiandir = File.dirname(File.absolute_path(watchfile))
      unless File.basename(debiandir) == 'debian'
        raise "path not a debian dir #{debiandir}"
      end
      @dir = File.dirname(debiandir)
      @watchfile = watchfile
      @mangle_download = mangle_download
    end

    def fetch(destdir)
      # FIXME: this should use DEHS output to get url and target name
      #   without downloading. then decide whether to wipe destdir and download
      #   or not.
      maybe_mangle do
        abort 'uscan failed' unless uscan(@dir, destdir)
        tar = Dir.glob("#{destdir}/*.orig.tar*")
        return nil unless tar.size == 1
        Tarball.new("#{destdir}/#{File.basename(tar[0])}")
      end
    end

    private

    def maybe_mangle(&block)
      orig_data = File.read(@watchfile)
      File.write(@watchfile, mangle_url(orig_data)) if @mangle_download
      block.yield
    ensure
      File.write(@watchfile, orig_data)
    end

    def mangle_url(data)
      data.gsub(%r{download.kde.org/stable/plasma},
                'download.kde.org.uk/stable/plasma')
    end

    def uscan(chdir, destdir)
      destdir = File.absolute_path(destdir)
      FileUtils.mkpath(destdir) unless Dir.exist?(destdir)
      system('uscan',
             '--verbose',
             '--download-current-version',
             "--destdir=#{destdir}",
             '--rename',
             chdir: chdir)
    end
  end
end
