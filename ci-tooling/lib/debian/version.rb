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

module Debian
  # A debian policy version handling class.
  class Version
    attr_accessor :epoch
    attr_accessor :upstream
    attr_accessor :revision

    def initialize(string)
      @epoch = nil
      @upstream = nil
      @revision = nil
      parse(string)
    end

    def full
      comps = []
      comps << "#{epoch}:" if epoch
      comps << upstream
      comps << "-#{revision}" if revision
      comps.join
    end

    def to_s
      full
    end

    # We could easily reimplement version comparision from Version.pm, but
    # it's mighty ugh because of string components, so in order to not run into
    # problems down the line, let's just consult with dpkg for now.
    def <=>(other)
      return 0 if full == other.full
      return 1 if compare_version(full, 'gt', other.full)
      return -1 if compare_version(full, 'lt', other.full)
      # A version can be stringwise different but have the same weight.
      # Make sure we cover that.
      return 0 if compare_version(full, 'eq', other.full)
    end

    private

    def compare_version(ours, op, theirs)
      run('--compare-versions', ours, op, theirs)
    end

    def run(*args)
      system('dpkg', *args)
    end

    def parse(string)
      regex = /^(?:(?<epoch>\d+):)?
                (?<upstream>[A-Za-z0-9.+:~-]+?)
                (?:-(?<revision>[A-Za-z0-9.~+]+))?$/x
      match = string.match(regex)
      @epoch = match[:epoch]
      @upstream = match[:upstream]
      @revision = match[:revision]
    end
  end
end
