# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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
    # @param watchfile String path to watch file for the fetcher
    # @param mangle_download Boolean whether to mangle KDE URIs to run through
    #   our internal sftp mapper (neon only)
    # @param series Array<String> list of series enabled for this fetcher.
    #   when this is set it will apt-get source the package from the archive
    #   as a first choice. Iff it cannot find the source with the version
    #   in the archive it uscans. (this prevents repack mismatches and saves
    #   a bit of time as our archive mirror is generally faster)
    def initialize(watchfile, mangle_download: false, series: [])
      @dir = File.dirname(debiandir_from(watchfile))
      @watchfile = watchfile
      @mangle_download = mangle_download
      @series = series
    end

    def fetch(destdir)
      # FIXME: this should use DEHS output to get url and target name
      #   without downloading. then decide whether to wipe destdir and download
      #   or not.
      maybe_mangle do
        make_dir(destdir)
        apt_source(destdir)
        uscan(@dir, destdir) unless @have_source
        tar = TarFinder.new(destdir).find_and_delete
        return tar unless tar # can be nil from pop
        Tarball.new("#{destdir}/#{File.basename(tar)}")
      end
    end

    private

    def make_dir(destdir)
      FileUtils.mkpath(destdir) unless Dir.exist?(destdir)
    end

    def debiandir_from(watchfile)
      unless File.basename(watchfile) == 'watch'
        raise "path not a watch file #{watchfile}"
      end
      debiandir = File.dirname(File.absolute_path(watchfile))
      unless File.basename(debiandir) == 'debian'
        raise "path not a debian dir #{debiandir}"
      end
      debiandir
    end

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

    def changelog
      @changelog ||= begin
        file = "#{@dir}/debian/changelog"
        raise "changelog not found at #{file}" unless File.exist?(file)
        Changelog.new(file)
      end
    end

    def current_version
      # uscan has a --download-current-version option this does however fail
      # to work for watch files with multiple entries as the version is cleared
      # inbetween loop runs so the second,thrid... runs will have no version set
      # and fail to resolve. To bypass this we'll pass the version explicilty
      # via --download-debversion which persists across loops.
      changelog.version(Changelog::ALL)
    end

    def apt_source(destdir)
      apt_sourcer = AptSourcer.new(changelog: changelog, destdir: destdir)
      @series.each do |series|
        tar = apt_sourcer.find_for(series: series)
        next unless tar
        warn "Found a suitable tarball: #{tar.basename}. Not uscanning..."
        @have_source = true
        break
      end
    end

    def uscan(chdir, destdir)
      destdir = File.absolute_path(destdir)
      FileUtils.mkpath(destdir) unless Dir.exist?(destdir)
      TTY::Command.new.run(
        'uscan',
        '--verbose',
        '--download-debversion', current_version,
        "--destdir=#{destdir}",
        '--rename',
        chdir: chdir
      )
    end

    # Helper to find the newest tar in a directory.
    class TarFinder
      attr_reader :dir

      def initialize(directory_with_tars)
        @dir = directory_with_tars
        warn "Hallo this is the tar finder. Running on #{@dir}"
      end

      def find_and_delete
        tars = all_tars_by_version.sort.to_h.values
        warn "I've found the following tars: #{tars}"
        # Automatically ditch all but the newest tarball. This prevents
        # preserved workspaces from getting littered with old tars.
        # Our version sorting logic prevents us from tripping over them though.
        tars[0..-2].each { |path| FileUtils.rm(path, verbose: true) }
        warn "The following tar is considered golden: #{tars[0]}"
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
    private_constant :TarFinder

    # Downloads source for a given debian/ dir via apt.
    class AptSourcer
      attr_reader :destdir
      attr_reader :name
      attr_reader :version

      # Dir is actually the parent dir of the debian/ dir.
      def initialize(changelog:, destdir:)
        @destdir = destdir
        @name = changelog.name
        warn 'Hola! This is the friendly AptSourcer from around the corner!'
        warn "I'll be sourcing #{@name} at #{@version} today."
        @version = changelog.version(Changelog::BASE | Changelog::BASESUFFIX)
      end

      def find_for(series:)
        TTY::Command.new.run!('apt-get', 'source',
                              '--download-only', '-t', series,
                              name,
                              chdir: destdir)
        find_tar
      ensure
        FileUtils.rm(Dir.glob("#{destdir}/*.debian.tar*"), verbose: true)
        FileUtils.rm(Dir.glob("#{destdir}/*.dsc"), verbose: true)
      end

      private

      def find_tar
        warn 'Telling TarFinder to go have a looksy.'
        tar = TarFinder.new(destdir).find_and_delete
        unless tar
          warn 'no tar'
          return nil
        end
        warn "Hooray, there's a tarball!"
        tarball = CI::Tarball.new(tar)
        return tarball if tarball.version == version
        warn "No goody version #{tarball.version}"
        nil
      end
    end
    private_constant :AptSourcer
  end
end
