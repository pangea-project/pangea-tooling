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

require_relative 'action'
require_relative 'client'

module DigitalOcean
  # Wrapper around various endpoints to create a Droplet object.
  class Droplet
    attr_accessor :client
    attr_accessor :id

    class << self
      # Creates a new Droplet instance from the name of a droplet (if it exists)
      def from_name(name, client = Client.new)
        drop = client.droplets.all.find { |x| x.name == name }
        return drop unless drop
        new(drop, client)
      end

      # Check if a droplet name exists
      def exist?(name, client = Client.new)
        client.droplets.all.any? { |x| x.name == name }
      end

      # Create a new standard droplet.
      def create(name, image_name, client = Client.new)
        image = client.snapshots.all.find { |x| x.name == image_name }

        raise "Found a droplet with name #{name} WTF" if exist?(name, client)
        new(client.droplets.create(new_droplet(name, image, client)), client)
      end

      def new_droplet(name, image, client)
        DropletKit::Droplet.new(
          name: name,
          region: 'fra1',
          image: ((image&.id) || 'ubuntu-16-04-x64'),
          size: 'c-2',
          ssh_keys: client.ssh_keys.all.collect(&:fingerprint),
          private_networking: true
        )
      end
    end

    def initialize(droplet_or_id, client)
      @client = client
      @id = droplet_or_id
      @id = droplet_or_id.id if droplet_or_id.is_a?(DropletKit::Droplet)
    end

    # Pass through not implemented methods to the API directly.
    #   - Methods ending in a ! get run as droplet_actions on the API and
    #     return an Action instance.
    #   - Methods implemented by a droplet resource (i.e. the native
    #     DropletKit object) get forwarded to it. Ruby 2.1 keywords get repacked
    #     so DropletKit doesn't throw up.
    #   - All other methods get sent to the droplets endpoint directly with
    #     the id of the droplet as argument.
    def method_missing(meth, *args, **kwords)
      return missing_action(meth, *args, **kwords) if meth.to_s[-1] == '!'
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
      p meth, args, { id: id }.merge(kwords)
      client.droplets.send(meth, *args, **{ id: id }.merge(kwords))
    end

    private

    def missing_action(name, *args, **kwords)
      name = name.to_s[0..-2].to_sym # strip trailing !
      action = client.droplet_actions.send(name, *args,
                                           **{ droplet_id: id }.merge(kwords))
      Action.new(action, client)
    end

    def resource
      client.droplets.find(id: id)
    end

    def to_str
      id
    end
  end
end
