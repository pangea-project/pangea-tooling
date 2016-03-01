# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

# FIXME: we manually load the reporter here because we install it from git
#   and would need bundler to load it properly, alas, bundler can't help
#   either because in containers we throw away gemfile and friends on
#   account of only using ci-tooling/
#   Ideally we'd simply have the gem updated properly so we don't need
#   git anymore.
begin
  require 'ci/reporter/rake/test_unit_loader'
rescue LoadError
  REPORTER = 'ci_reporter_test_unit-5c6c30d120a3'.freeze
  require format("#{Gem.default_dir}/bundler/gems/#{REPORTER}/lib/%s",
                 'ci/reporter/rake/test_unit_loader')
end
require 'test/unit'

module Lint
  # Convenience class to test lint results
  class ResultTest < Test::Unit::TestCase
    def assert_result(result)
      notify(result.warnings.join("\n")) unless result.warnings.empty?
      notify(result.informations.join("\n")) unless result.informations.empty?
      # Flunking fails the test entirely, so this needs to be at the very end!
      flunk(result.errors.join("\n")) unless result.errors.empty?
      # FIXME: valid means nothing concrete so we skip it for now
      # assert(result.valid, "Lint result not valid ::\n #{result.inspect}")
    end
  end
end
