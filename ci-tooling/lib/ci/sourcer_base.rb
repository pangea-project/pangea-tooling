# frozen_string_literal: true
#
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
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

require 'fileutils'
require 'git_clone_url'
require 'rugged'
require 'logger'

require_relative 'dependency_resolver'
require_relative '../debian/control'

module CI
  # Automatically inject/update Vcs- control fields to match where we actually
  # build things from.
  module ControlVCSInjector
    def copy_source_tree(source_dir, *args)
      ret = super
      return ret if File.basename(source_dir) != 'packaging'
      url = vcs_url_of(source_dir)
      return ret unless url
      edit_control("#{@build_dir}/source/") do |control|
        fill_vcs_fields(control, url)
      end
      ret
    end

    private

    def control_log
      @control_log ||= Logger.new(STDOUT).tap { |l| l.progname = 'control' }
    end

    def vcs_url_of(path)
      return nil unless Dir.exist?(path)
      repo = Rugged::Repository.discover(path)
      remote = repo.remotes['origin']
      remote.url
    rescue Rugged::RepositoryError
      control_log.warn "Failed to resolve repo of #{path}"
      nil
    end

    def fill_vcs_fields(control, url)
      control_log.info "Automatically filling VCS fields pointing to #{url}"
      control.source['Vcs-Git'] = url
      uri = GitCloneUrl.parse(url)
      uri.path = uri.path.gsub('.git', '') # sanitize
      control.source['Vcs-Browser'] = vcs_browser(uri) || url
      control.dump
    end

    def vcs_browser(uri)
      case uri.host
      when 'anongit.neon.kde.org', 'git.neon.kde.org'
        "https://packaging.neon.kde.org#{uri.path}.git"
      # :nocov: no point covering this besides the interpolation
      when 'git.debian.org', 'anonscm.debian.org'
        "https://anonscm.debian.org/cgit#{uri.path}.git"
      when 'github.com'
        "https://github.com#{uri.path}"
      end
      # :nocov:
    end
  end

  # Base class for sourcer implementations.
  class SourcerBase
    prepend ControlVCSInjector

    class BuildPackageError < StandardError; end

    private

    def initialize(release:, strip_symbols:, restricted_packaging_copy:)
      @release = release # e.g. vivid
      @strip_symbols = strip_symbols
      @restricted_packaging_copy = restricted_packaging_copy

      # vcs
      @packaging_dir = File.absolute_path('packaging').freeze
      # orig
      @packagingdir = @packaging_dir.freeze

      # vcs
      @build_dir = "#{Dir.pwd}/build"
      # orig
      @builddir = @build_dir.freeze
      FileUtils.rm_r(@build_dir) if Dir.exist?(@build_dir)
      Dir.mkdir(@build_dir)

      # vcs
      # TODO:
      # orig
      @sourcepath = "#{@builddir}/source" # Created by extract.
    end

    def mangle_symbols
      # Rip out symbol files unless we are on latest
      return unless @strip_symbols
      symbols = Dir.glob('debian/symbols') +
                Dir.glob('debian/*.symbols') +
                Dir.glob('debian/*.symbols.*') +
                Dir.glob('debian/*.acc') +
                Dir.glob('debian/*.acc.in')
      symbols.each { |s| FileUtils.rm(s) }
    end

    def edit_control(dir, &_block)
      control = Debian::Control.new(dir)
      control.parse!
      yield control
      File.write("#{dir}/debian/control", control.dump)
    end

    def create_changelog_entry(version, message = 'Automatic CI Build')
      dch = [
        'dch',
        '--force-bad-version',
        '--distribution', @release,
        '--newversion', version,
        message
      ]
      # dch cannot actually fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      raise 'Failed to create changelog entry' unless system(*dch)
    end

    def mangle_maintainer
      name = ENV['DEBFULLNAME']
      email = ENV['DEBEMAIL']
      unless name
        warn 'Not mangling maintainer as no debfullname is set'
        return
      end
      edit_control(Dir.pwd) do |control|
        control.source['Maintainer'] = "#{name} <#{email || 'null@null.org'}>"
      end
    end

    def dpkg_buildpackage
      mangle_maintainer unless ENV['NOMANGLE_MAINTAINER']
      run_dpkg_buildpackage_with_deps
    end

    def run_dpkg_buildpackage_with_deps
      # By default we'll not install build depends on the package and hope
      # it generates a sources even without build deps present.
      # If this fails we'll rescue the error *once* and resolve the deps.
      with_deps ||= false
      run_dpkg_buildpackage
    rescue BuildPackageError => e
      raise e if with_deps # Failed even with deps installed: give up
      warn 'Failed to build source. Trying again with all build deps installed!'
      with_deps = true
      resolve_deps
      retry
    end

    def run_dpkg_buildpackage
      args = [
        'dpkg-buildpackage',
        '-us', '-uc', # Do not sign .dsc / .changes
        '-S', # Only build source
        '-d' # Do not enforce build-depends
      ]
      raise BuildPackageError, 'dpkg-buildpackage failed!' unless system(*args)
    end

    def resolve_deps
      DependencyResolver.resolve(Dir.pwd, retries: 3, bin_only: true)
    rescue DependencyResolver::ResolutionError
      raise BuildPackageError, <<-ERRORMSG
Failed to build source. The source failed to build, then we tried to install
build deps but it still failed. The error may likely be further up
(before we tried to install dependencies...)
      ERRORMSG
    end

    # Copies a source tree to the target source directory
    # @param source_dir the directory to copy from (all content within will
    #   be copied)
    # @note this will create @build_dir/source if it doesn't exist
    # @note this will strip the copied source of version control directories
    def copy_source_tree(source_dir, dir = '.')
      # /. is fileutils notation for recursive content
      FileUtils.mkpath("#{@build_dir}/source")
      if Dir.exist?(source_dir)
        FileUtils.cp_r("#{source_dir}/#{dir}",
                       "#{@build_dir}/source/",
                       verbose: true)
      end
      %w[.bzr .git .hg .svn].each do |vcs_dir|
        FileUtils.rm_rf(Dir.glob("#{@build_dir}/source/**/#{vcs_dir}"))
      end
    end
  end
end
