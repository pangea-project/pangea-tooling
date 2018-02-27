# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
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
require 'tty-command'

require_relative '../tarball'
require_relative '../../debian/changelog'
require_relative '../../debian/version'

module CI
  # Fetch tarballs via uscan using debian/watch.
  class WatchTarFetcher
    # Helper to find the newest tar in a directory.
    class TarFinder
      attr_reader :dir

      def initialize(directory_with_tars)
        @dir = directory_with_tars
      end

      def find
        tars = all_tars_by_version.sort.to_h.values
        # Automatically ditch all but the newest tarball. This prevents
        # preserved workspaces from getting littered with old tars.
        # Our version sorting logic prevents us from tripping over them though.
        tars[0..-2].each { |path| FileUtils.rm(path, verbose: true) }
        tars.pop
      end

      private

      def all_tars
        Dir.glob("#{dir}/*.orig.tar*").reject do |x|
          %w[.asc .sig].any? { |ext| x.end_with?(ext) }
        end
      end

      def all_tars_by_version
        all_tars.map do |x|
          [Debian::Version.new(version_from_file(x)), x]
        end.to_h
      end

      def version_from_file(path)
        filename = File.basename(path)
        filename.slice(/_.*/)[1..-1].split('.orig.')[0]
      end
    end

    def initialize(watchfile, mangle_download: false)
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
        uscan(@dir, destdir)
        tar = TarFinder.new(destdir).find
        return tar unless tar # can be nil from pop
        Tarball.new("#{destdir}/#{File.basename(tar)}")
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
      # The download.kde.internal.neon.kde.org domain is not publicly available!
      # Only available through blue system's internal DNS.
      data.gsub(%r{download.kde.org/stable/},
                'download.kde.internal.neon.kde.org:9191/stable/')
    end

    def current_version
      # uscan has a --download-current-version option this does however fail
      # to work for watch files with multiple entries as the version is cleared
      # inbetween loop runs so the second,thrid... runs will have no version set
      # and fail to resolve. To bypass this we'll pass the version explicilty
      # via --download-debversion which persists across loops.
      file = "#{@dir}/debian/changelog"
      raise "changelog not found at #{file}" unless File.exist?(file)
      Changelog.new(file).version(Changelog::ALL)
    end

    def overlay_path
      # Use parallel xz via our overlay. This allows much faster re-compression
      # incase the package needs to perform a dfsg repack.
      overlay_path = File.expand_path("#{__dir__}/../../../../overlay-bin")
      return overlay_path if File.exist?(overlay_path)
      raise "could not find overlay bins in #{overlay_path}"
    end

    # rubocop:disable Metrics/MethodLength
    # This is so long because we want readable cmdline args.
    # Should you add excessive amounts of logic here enable the metric again!
    def uscan(chdir, destdir)
      destdir = File.absolute_path(destdir)
      FileUtils.mkpath(destdir) unless Dir.exist?(destdir)
      TTY::Command.new.run(
        'uscan',
        '--verbose', '--rename',
        '--download-debversion', current_version,
        "--destdir=#{destdir}",
        chdir: chdir,
        env: { PATH: [overlay_path, ENV.fetch('PATH')].join(':'),
               OVERLAY_PARALLEL_COMPRESSION: true }
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
