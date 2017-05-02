# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
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

require 'erb'
require 'pathname'

# Base class for job template.
class Template
  # [String] Directory with config files. Absolute.
  attr_reader :config_directory
  # [String] Template file for this job. Absolute.
  attr_reader :template_path

  def initialize(template_name)
    @config_directory = "#{@@flavor_dir}/config/"
    @flavor_template_directory = "#{@@flavor_dir}/templates/"
    @core_template_directory = "#{__dir__}/templates/"
    # Find template in preferrably the flavor dir, fall back to core directory.
    # This allows sharing the template.
    template_dirs = [@flavor_template_directory, @core_template_directory]
    return if template_dirs.any? do |dir|
      @template_directory = dir
      @template_path = "#{@template_directory}#{template_name}"
      File.exist?(@template_path)
    end
    raise "Template #{template_name} not found at #{@template_path}"
  end

  def self.flavor_dir=(dir)
    # This is handled as a class variable because we want all instances of
    # JenkinsJob to have the same flavor set. Class instance variables OTOH
    # would need additional code to properly apply it to all instances, which
    # is mostly useless.
    @@flavor_dir = dir # rubocop:disable Style/ClassVars
  end

  def self.flavor_dir
    @@flavor_dir
  end

  def render_template
    render(@template_path)
  end

  def render(path)
    return '' unless path
    data = if Pathname.new(path).absolute?
             File.read(path)
           else
             File.read("#{@template_directory}/#{path}")
           end
    ERB.new(data).result(binding)
  end

  private

  def xml_debug(data)
    require 'rexml/document'
    doc = REXML::Document.new(data)
    REXML::Formatters::Pretty.new.write(doc, $stdout)
  end
end
