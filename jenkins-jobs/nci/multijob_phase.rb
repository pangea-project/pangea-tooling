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

require_relative '../template'

# a phase partial
class MultiJobPhase < Template
  # @!attribute [r] phase_name
  #   @return [String] name of the phase
  attr_reader :phase_name

  # @!attribute [r] phased_jobs
  #   @return [Array<String>] name of the phased jobs
  attr_reader :phased_jobs

  # @param phase_name see {#phase_name}
  # @param phased_jobs see {#phased_jobs}
  def initialize(phase_name:, phased_jobs:)
    super("#{File.basename(__FILE__, '.rb')}.xml.erb")
    @phase_name = phase_name
    @phased_jobs = phased_jobs
  end
end
