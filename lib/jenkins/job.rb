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

require_relative '../../ci-tooling/lib/jenkins'

module Jenkins
  # A Jenkins Job.
  # Gives jobs a class so one can use it like a bloody OOP construct rather than
  # I don't even know what the default api client thing does...
  class Job
    attr_reader :name

    def initialize(name, client = JenkinsApi::Client.new)
      @client = client
      @name = name
    end

    def delete!
      @client.job.delete(@name)
    end

    def wipe!
      @client.job.wipe_out_workspace(@name)
    end

    def enable!
      @client.job.enable(@name)
    end

    def disable!
      @client.job.disable(@name)
    end

    def remove_downstream_projects
      @client.job.remove_downstream_projects(@name)
    end

    def method_missing(name, *args)
      @client.job.send(name, *([@name] + args))
    end
  end
end
