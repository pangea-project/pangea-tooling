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

require_relative '../nci/docker_hub_check'

module NCI
  module DockerHubTest
    class NCIDockerHubTest < TestCase
      def setup
        @status = {"dev-stable"=>0, "dev-unstable"=>0, "dev-unstable-development"=>-1, "latest"=>0, "user"=>0, "user-lts"=>0}
      end

      def test_run
        puts data('dockerhub.json')
        checker = DockerHubCheck.new
        status = checker.build_statuses(data('dockerhub.json'))
        assert_equal(status, @status)
      end
      
      def test_email
        checker = DockerHubCheck.new
        checker.build_statuses(data('dockerhub.json'))
        assert_equal("dev-unstable-development: -1\n", checker.format_email)
      end
    end
  end
end
