# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../tarball'

module CI
  # Fetch tarballs from the jenkins debscm dir.
  class DebSCMFetcher
    def initialize
      @dir = File.join(Dir.pwd, 'debscm')
    end

    def fetch(_destdir)
      # TODO: should we maybe copy the crap from debscm into destdir?
      #   it seems a bit silly since we already have debscm in the workspace
      #   anyway though...
      tars = Dir.glob("#{@dir}/*.tar*").reject { |x| x.include?('.debian.tar') }
      raise "Expected exactly one tar, got: #{tars}" if tars.size != 1
      dscs = Dir.glob("#{@dir}/*.dsc")
      raise "Expected exactly one dsc, got: #{dscs}" if dscs.size != 1
      DSCTarball.new(tars[0], dsc: dscs[0])
    end
  end
end
