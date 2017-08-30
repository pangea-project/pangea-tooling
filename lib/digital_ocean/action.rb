# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative '../../ci-tooling/lib/retry'
require_relative 'client'

module DigitalOcean
  # Convenience wrapper around actions.
  class Action
    attr_accessor :client
    attr_accessor :id

    class << self
      def wait(sleep_for: 16, retries: 100_000, error: nil)
        broken = false
        retries.times do
          if yield
            broken = true
            break
          end
          sleep(sleep_for)
        end
        raise error if error && !broken
        broken
      end
    end

    def initialize(action_or_id, client)
      @client = client
      @id = action_or_id
      @id = action_or_id.id if action_or_id.is_a?(DropletKit::Action)
    end

    def until_status(state)
      count = 0
      until resource.status == state
        yield count
        count += 1
        sleep 16
      end
    end

    def complete!(&block)
      until_status('completed', &block)
    end

    # Forward not implemented methods.
    #   - Methods implemented by the resource are forwarded to the resource
    def method_missing(meth, *args, **kwords)
      # return missing_action(action, *args) if meth.to_s[-1] == '!'
      res = resource
      if res.respond_to?(meth)
        # The droplet_kit resource mapping crap is fairly shitty and doesn't
        # manage to handle kwords properly, pack it into a ruby <=2.0 style
        # array.
        argument_pack = []
        argument_pack += args unless args.empty?
        argument_pack << kwords unless kwords.empty?
        return res.send(meth, *argument_pack) if res.respond_to?(meth)
      end
      super
    end

    private

    def resource
      client.actions.find(id: id)
    end
  end
end
