# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

# NB: this is used during deployment. Do not require non-core gems globally!
#   require during execution, and make sure the gems are actually installed or
#   fallback logic is in place.

# Bundler can have itself injected in the env preventing bundlers forked from
# ruby to work correctly. This helper helps with running bundlers in a way
# that they do not have a "polluted" environment.
module RakeBundleHelper
  class << self
    def run(*args)
      require 'bundler'
      Bundler.clean_system(*args)
    rescue NameError, LoadError
      system(*args)
    end
  end
end

def bundle(*args)
  args = ['bundle'] + args
  RakeBundleHelper.run(*args)
  raise "Command failed (#{$?}) #{args}" unless $?.to_i.zero?
end
