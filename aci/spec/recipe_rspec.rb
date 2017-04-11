#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
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
require_relative '../libs/recipe'
require_relative '../libs/sources'
require_relative '../libs/metadata'
require 'yaml'
require 'erb'

describe Recipe do
  app = Recipe.new(name: Metadata::PROJECT, binary: Metadata::METADATA['binary'])
  describe "#initialize" do
    it "Sets the application name" do
      expect(app.name).to eq Metadata::PROJECT
      expect(app.binary).to eq Metadata::METADATA['binary']
    end
  end

  describe 'generate_appimage' do
    it 'Generate the appimage' do
      arch = `arch`
      File.write('/in/Recipe', app.render)
      expect(app.generate_appimage()).to eq 0
    end
  end
end
