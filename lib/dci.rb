# frozen_string_literal: true
require_relative 'xci'
require 'ostruct'
require 'yaml'

# Debian CI specific data.
module DCI
  extend XCI

  module_function

  def arm_boards
    # To define which board we are building on in ARM jobs..
    data.fetch('arm_boards')
  end

  def architecture(release_data)
    release_data.arch
  end

  def release_types
    @data['release_types']
  end

  def releases_by_type(release_type)
    releases_by_type = @data[release_type]
    releases_by_type
  end

  def get_release_data(rel)
    releases = @data[:releases]
    release_data releases.fetch(rel)
    release.new(release_data.name, release_data.release_type, release_data.arch, release_data.components)
    release
  end

  def components(release_data)
    release_data.components
  end
  
  def data_file_name
    @data_file_name ||= "#{to_s.downcase}.yaml"
  end

  def data_dir
    @data_dir ||= File.join(File.dirname(__dir__), 'data')
  end

  def data_dir=(data_dir)
    reset!
    @data_dir = data_dir
  end

  def data
    release = Struct.new(:name, :release_type, :arch, :components)
    file = File.join(data_dir, 'dci.yaml')
    raise "Data file not found (#{file})" unless File.exist?(file)

    @data = YAML.load(File.read(file))
    @data.each_value(&:freeze) # May be worth looking into a deep freeze gem.
  end

end
