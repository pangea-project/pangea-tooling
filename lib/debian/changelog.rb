# frozen_string_literal: true
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'

# Debian changelog.
class Changelog
  # This is a simplified parser that only reads the first line (latest entry)
  # to get version and name of the package. It is used because parsechangelog
  # has been observed to be incredibly slow at what it does, while it in fact
  # provides more information than we need. So here's the super optimized
  # version for us.

  attr_reader :name

  EPOCH      = 0b1
  BASE       = 0b10
  BASESUFFIX = 0b100
  REVISION   = 0b1000
  ALL        = 0b1111

  class << self
    def new_version_cmd(version, distribution:, message:)
      [
        'dch',
        '--force-bad-version',
        '--force-distribution',
        '--distribution', distribution,
        '--newversion', version,
        message
      ]
    end

    # Make a new entry via dch
    # NB: this may need refactoring into its own class if the arguments
    # blow up or the requirements get more complicated. It is only here
    # in this class because I'm lazy -sitter
    def new_version!(version, distribution:, message:, chdir: Dir.pwd)
      dch = new_version_cmd(version, distribution: distribution, message: message)
      # dch cannot realy fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      TTY::Command.new.run(*dch, chdir: chdir)
    end
  end

  def initialize(pwd = Dir.pwd)
    @file = File.file?(pwd) ? pwd : "#{pwd}/debian/changelog"
    @file = File.absolute_path(@file)
    reload!
  end

  def version(flags = ALL)
    ret = ''
    ret += @comps[:epoch] if flagged?(flags, EPOCH)
    ret += @comps[:base] if flagged?(flags, BASE)
    ret += @comps[:base_suffix] if flagged?(flags, BASESUFFIX)
    ret += @comps[:revision] if flagged?(flags, REVISION)
    ret
  end

  # Make a new entry via dch (and reload). Delegates to class level function.
  def new_version!(*args, **kwords)
    chdir = File.dirname(File.dirname(@file)) # two up from debian/changelog
    self.class.new_version!(*args, **kwords, chdir: chdir)
    reload!
  end

  private

  def flagged?(flags, type)
    flags & type > 0
  end

  # right parition
  # @return [Array] of size 2 with the remainder of str as first and the right
  #   sub-string as last.
  # @note The sub-string always contains the separator itself as well.
  def rpart(str, sep)
    first, second, third = str.rpartition(sep)
    return [third, ''] if first.empty? && second.empty?

    [first, [second, third].join]
  end

  def fill_comps(version)
    # Split the entire thing.
    @comps = {}
    # For reasons beyond my apprehension the original behavior is to retain
    # the separators in the results, which requires somewhat acrobatic
    # partitioning to keep them around for compatibility.
    version, @comps[:revision] = rpart(version, '-')
    git_seperator = version.include?('~git') ? '~git' : '+git'
    version, @comps[:base_suffix] = rpart(version, git_seperator)
    @comps[:epoch], _, @comps[:base] = version.rpartition(':')
    @comps[:epoch] += ':' unless @comps[:epoch].empty?
  end

  def reload!
    line = File.open(@file, &:gets)
    # plasma-framework (5.3.0-0ubuntu1) utopic; urgency=medium
    match = line.match(/^(.*) \((.*)\) (.+); urgency=(\w+)/)
    # Need a  match and 5 elements.
    # 0: full match
    # 1: source name
    # 2: version
    # 3: distribution series
    # 4: urgency
    raise 'E: Cannot read debian/changelog' if match.nil? || match.size != 5

    @name = match[1]
    @version = match[2]
    # Don't even bother with the rest, we don't care right now.

    fill_comps(@version.dup)
  end
end

module Debian
  Changelog = ::Changelog
end
