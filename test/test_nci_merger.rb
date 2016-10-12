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

require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'
require 'rugged'

require_relative '../nci/debian-merge/merger'

module NCI
  module DebianMerge
    class NCITagMergerTest < TestCase
      def setup
      end

      def test_run
        tag_base = 'tagi'
        url = 'http://abc'
        json = { repos: [url], tag_base: tag_base }
        File.write('data.json', JSON.generate(json))

        repo = mock('repo')
        Repository.expects(:clone_into).with { |*args| args[0] == url }.returns(repo)
        repo.expects(:tag_base=).with(tag_base)
        repo.expects(:merge)
        repo.expects(:push)

        Merger.new.run
      end

      def test_run_fail
        tag_base = 'tagi'
        url = 'http://abc'
        json = { repos: [url], tag_base: tag_base }
        File.write('data.json', JSON.generate(json))

        repo = mock('repo')
        Repository.expects(:clone_into).with { |*args| args[0] == url }.returns(repo)
        repo.expects(:tag_base=).with(tag_base)
        repo.expects(:merge).raises('kittens')

        assert_raises RuntimeError do
          Merger.new.run
        end
      end

      def test_merge_future
        tag_base = 'tagi'
        url = 'http://abc'
        json = { repos: [url], tag_base: tag_base }

        repo = mock('repo')
        Repository.expects(:clone_into).with(url, tag_base).returns(repo)
        repo.expects(:tag_base=).with(tag_base)
        repo.expects(:merge)

        File.write('data.json', JSON.generate(json))
        assert_is_a(Merger.new.merge(url, tag_base), Concurrent::Future)
      end
    end
  end
end
