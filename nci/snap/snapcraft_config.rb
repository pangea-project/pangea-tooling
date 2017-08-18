# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

module NCI
  module Snap
    class SnapcraftConfig
      module AttrRecorder
        def attr_accessor(*args)
          record_readable(*args)
          super
        end

        def attr_reader(*args)
          record_readable(*args)
          super
        end

        def record_readable(*args)
          @readable_attrs ||= []
          @readable_attrs += args
        end

        def readable_attrs
          @readable_attrs
        end
      end

      module YamlAttributer
        def attr_name_to_yaml(readable_attrs)
          y = readable_attrs.to_s.tr('_', '-')
          y = 'prime' if y == 'snap'
          y
        end

        def encode_with(c)
          c.tag = nil # Unset the tag to prevent clutter
          self.class.readable_attrs.each do |readable_attrs|
            next unless (data = method(readable_attrs).call)
            next if data.respond_to?(:empty?) && data.empty?
            c[attr_name_to_yaml(readable_attrs)] = data
          end
          super(c) if defined?(super)
        end
      end

      class Part
        extend AttrRecorder
        prepend YamlAttributer

        # Array<String>
        attr_accessor :after
        # String
        attr_accessor :plugin
        # Array<String>
        attr_accessor :build_packages
        # Array<String>
        attr_accessor :stage_packages
        # Hash
        attr_accessor :filesets
        # Array<String>
        attr_accessor :stage
        # Array<String>
        attr_accessor :snap
        # Hash<String, String>
        attr_accessor :organize

        # Array<String>
        attr_accessor :debs
        # Array<String>
        attr_accessor :exclude_debs

        attr_accessor :source
        attr_accessor :source_type
        attr_accessor :source_depth
        attr_accessor :source_branch
        attr_accessor :source_commit
        attr_accessor :source_tag
        attr_accessor :source_subdir

        attr_accessor :configflags

        def initialize(hash = {})
          from_h(hash)
          init_defaults
        end

        def init_defaults
          @after ||= []
          @plugin ||= 'nil'
          @build_packages ||= []
          @stage_packages ||= []
          @filesets ||= {}
          @filesets['exclusion'] ||= []
          @filesets['exclusion'] += %w[
            -usr/lib/*/cmake/*
            -usr/include/*
            -usr/share/ECM/*
            -usr/share/doc/*
            -usr/share/man/*
            -usr/share/icons/breeze-dark*
            -usr/bin/X11
            -usr/lib/gcc/x86_64-linux-gnu/6.0.0
          ]
          @stage ||= []
          @snap ||= []
          @snap += %w[$exclusion]
        end

        def from_h(h)
          h.each do |k, v|
            k = 'snap' if k == 'prime'
            send("#{k.tr('-', '_')}=", v)
          end
        end
      end

      # This is really ContentSlot :/
      class Slot
        extend AttrRecorder
        prepend YamlAttributer

        attr_accessor :content
        attr_accessor :interface
        attr_accessor :read
      end

      class DBusSlot
        extend AttrRecorder
        prepend YamlAttributer

        attr_accessor :interface
        attr_accessor :name
        attr_accessor :bus

        def initialize
          @interface = 'dbus'
        end
      end

      class Plug
        extend AttrRecorder
        prepend YamlAttributer

        attr_accessor :content
        attr_accessor :interface
        attr_accessor :default_provider
        attr_accessor :target
      end

      class App
        extend AttrRecorder
        prepend YamlAttributer

        attr_accessor :command
        attr_accessor :plugs
      end

      extend AttrRecorder
      prepend YamlAttributer

      attr_accessor :name
      attr_accessor :version
      attr_accessor :summary
      attr_accessor :description
      attr_accessor :confinement
      attr_accessor :grade
      attr_accessor :apps
      attr_accessor :slots
      attr_accessor :plugs
      attr_accessor :parts

      def initialize
        @parts = {}
        @slots = {}
        @plugs = {}
        @apps = {}
      end
    end
  end
end
