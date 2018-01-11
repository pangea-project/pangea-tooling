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

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/rake/bundle'

require 'mocha/test_unit'

# Hack
# https://github.com/bundler/bundler/issues/6252
module BundlerOverlay
  def frozen?
    if caller_locations.any?{ |x| x.absolute_path.include?('lib/mocha') }
      return false
    end
    super
  end
end

module Bundler
  class << self
    prepend BundlerOverlay
  end
end

class RakeBundleTest < TestCase
  def setup
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never
    # Also disable all bundler fork invocation.
    Bundler.expects(:clean_system).never
    Bundler.expects(:clean_exec).never
  end

  def test_bundle
    Bundler.expects(:clean_system)
           .with('bundle', 'pack')
    bundle(*%w[pack])
  end

  def test_bundle_nameerror
    seq = sequence('bundle')
    Bundler.expects(:clean_system)
           .with('bundle', 'pack')
           .raises(NameError)
           .in_sequence(seq)
    Object.any_instance
          .expects(:system)
          .with('bundle', 'pack')
          .in_sequence(seq)
    bundle(*%w[pack])
  end
end
