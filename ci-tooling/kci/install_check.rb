#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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
require 'logger'
require 'logger/colors'
require 'open3'
require 'tmpdir'

require_relative 'lib/apt'
require_relative 'lib/aptly-ext/filter'
require_relative 'lib/dpkg'
require_relative 'lib/lp'
require_relative 'lib/repo_abstraction'
require_relative 'lib/retry'
require_relative 'lib/thread_pool'

# Base class for install checks, isolating common logic.
class InstallCheckBase
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def run(candidate_ppa, target_ppa)
    candidate_ppa.remove # remove live before attempting to use daily.

    # Add the present daily snapshot, install everything.
    # If this fails then the current snapshot is kaputsies....
    if target_ppa.add
      unless target_ppa.install
        @log.info 'daily failed to install.'
        daily_purged = target_ppa.purge
        unless daily_purged
          @log.info <<-EOS.tr($/, '')
daily failed to install and then failed to purge. Maybe check maintscripts?
          EOS
        end
      end
    end
    @log.unknown 'done with daily'

    # NOTE: If daily failed to install, no matter if we can upgrade live it is
    # an improvement just as long as it can be installed...
    # So we purged daily again, and even if that fails we try to install live
    # to see what happens. If live is ok we are good, otherwise we would fail
    # anyway

    candidate_ppa.add
    unless candidate_ppa.install
      @log.error 'all is vain! live PPA is not installing!'
      exit 1
    end

    # All is lovely. Let's make sure all live packages uninstall again
    # (maintscripts!) and then start the promotion.
    unless candidate_ppa.purge
      @log.error <<-EOS.tr($/, '')
live PPA installed just fine, but can not be uninstalled again. Maybe check
maintscripts?
      EOS
      exit 1
    end

    @log.info "writing package list in #{Dir.pwd}"
    File.write('sources-list.json', JSON.generate(candidate_ppa.sources))
  end
end

# Kubuntu install check.
class InstallCheck < InstallCheckBase
  def install_fake_pkg(name)
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        Dir.mkdir(name)
        Dir.mkdir("#{name}/DEBIAN")
        File.write("#{name}/DEBIAN/control", <<-EOF.gsub(/^\s+/, ''))
        Package: #{name}
        Version: 999:999
        Architecture: all
        Maintainer: Harald Sitter <sitter@kde.org>
        Description: fake override package for kubuntu ci install checks
        EOF
        system("dpkg-deb -b #{name} #{name}.deb")
        DPKG.dpkg(['-i', "#{name}.deb"])
      end
    end
  end

  def run(candidate_ppa, target_ppa)
    if Process.uid.to_i.zero?
      # Disable invoke-rc.d because it is crap and causes useless failure on
      # install when it fails to detect upstart/systemd running and tries to
      # invoke a sysv script that does not exist.
      File.write('/usr/sbin/invoke-rc.d', "#!/bin/sh\n")
      # Speed up dpkg
      File.write('/etc/dpkg/dpkg.cfg.d/02apt-speedup', "force-unsafe-io\n")
      # Prevent xapian from slowing down the test.
      # Install a fake package to prevent it from installing and doing anything.
      # This does render it non-functional but since we do not require the
      # database anyway this is the apparently only way we can make sure
      # that it doesn't create its stupid database. The CI hosts have really
      # bad IO performance making a full index take more than half an hour.
      install_fake_pkg('apt-xapian-index')
      File.open('/usr/sbin/update-apt-xapian-index', 'w', 0o755) do |f|
        f.write("#!/bin/sh\n")
      end
      # Also install a fake resolvconf because docker is a piece of shit cunt
      # https://github.com/docker/docker/issues/1297
      install_fake_pkg('resolvconf')
      # Disable manpage database updates
      Open3.popen3('debconf-set-selections') do |stdin, _stdo, stderr, wait_thr|
        stdin.puts('man-db man-db/auto-update boolean false')
        stdin.close
        wait_thr.join
        puts stderr.read
      end
      # Make sure everything is up-to-date.
      abort 'failed to update' unless Apt.update
      abort 'failed to dist upgrade' unless Apt.dist_upgrade
      # Install ubuntu-minmal first to make sure foundations nonsense isn't
      # going to make the test fail half way through.
      abort 'failed to install minimal' unless Apt.install('ubuntu-minimal')
      # Because dependencies are fucked
      # [14:27] <sitter> dictionaries-common is a crap package
      # [14:27] <sitter> it suggests a wordlist but doesn't pre-depend them or
      # anything, intead it just craps out if a wordlist provider is installed
      # but there is no wordlist -.-
      system('apt-get install wamerican')
    end

    super
  end
end

if __FILE__ == $PROGRAM_NAME
  LOG = Logger.new(STDERR)
  LOG.level = Logger::INFO

  Project = Struct.new(:series, :stability)
  project = Project.new(ENV.fetch('DIST'), ENV.fetch('TYPE'))

  candiate_ppa = CiPPA.new("#{project.stability}-daily", project.series)
  target_ppa = CiPPA.new(project.stability.to_s, project.series)
  InstallCheck.new.run(candiate_ppa, target_ppa)
  exit 0
end
