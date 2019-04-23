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

require_relative 'extender'

module NCI
  module Snap
    # Extends snapcraft's manifest file with the packages we have in our content
    # snap to prevent these packages form getting staged again.
    class ManifestExtender < Extender
      MANIFEST_PATH =
        '/usr/lib/python3/dist-packages/snapcraft/internal/repo/manifest.txt'
      SNAP_MANIFEST_PATH =
        '/snap/snapcraft/current/lib/python3.5/site-packages/snapcraft/internal/repo/manifest.txt'

      class << self
        attr_writer :manifest_path
        def manifest_path
          @manifest_path ||= if File.exist?(SNAP_MANIFEST_PATH)
                               SNAP_MANIFEST_PATH
                             else
                               MANIFEST_PATH
                             end
        end
      end

      def run
        FileUtils.cp(manifest_path, "#{manifest_path}.bak", verbose: true)
        append!
        # for diganostic purposes we'll make a copy of the extended version...
        FileUtils.cp(manifest_path, "#{manifest_path}.ext", verbose: true)

        yield
      ensure
        if File.exist?("#{manifest_path}.bak")
          FileUtils.cp("#{manifest_path}.bak", manifest_path, verbose: true)
        end
      end

      private

      def append!
        unless kf5_build_snap?
          warn 'NOT A KF5 BUILD SNAP USER. NOT MANGLING MANIFEST!'
          return
        end

        File.open(manifest_path, 'a') { |f| f.puts(exclusion.join("\n")) }
      end

      def kf5_build_snap?
        data['parts'].any? do |_name, part|
          is = part.build_snaps&.any? { |x| x.include?('kde-frameworks-5') }
          use = part.configflags&.any? { |x| x.include?('kde-frameworks-5') }
          is || use
        end
      end

      def exclusion
        pkgs = content_stage.dup
        # Include dev packages in case someone was lazy and used a dev package
        # as stage package. This is technically a bit wrong since the dev stage
        # is not part of the content snap, but if one takes the dev shortcut all
        # bets are off anyway. It's either this or having oversized snaps.
        pkgs += dev_stage if any_dev?
        # Do not pull in dev packages that are in the stage-packages list.
        # They may be used to easily get the libs they depend on, but they
        # themselves have no business being in the stage really.
        # Fairly hacky shortcut this.
        pkgs += staged_devs
        # never let gtk be pulled in, it should be in the content-snap
        pkgs << 'qt5-gtk-platformtheme' unless ENV['PANGEA_UNDER_TEST']
        pkgs.uniq
      end

      def staged_devs
        devs = []
        data['parts'].values.collect do |part|
          part&.stage_packages&.each { |x| devs << x if x.end_with?('-dev') }
        end
        devs.uniq.compact
      end

      def manifest_path
        self.class.manifest_path
      end

      # not used; really should be renamed to run
      def extend; end

      def any_dev?
        @any_dev ||= !staged_devs.empty?
      end
    end
  end
end
