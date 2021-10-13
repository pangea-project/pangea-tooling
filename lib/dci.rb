# frozen_string_literal: true
require_relative 'xci'

# Debian CI specific data.
module DCI
  extend XCI

  module_function

  def arm_boards
    data['arm_boards']
  end

  def arm?(rel)
    return true if rel.end_with?('c1' || 'rock64' || 'rpi4')
  end

  def arm_board_by_release(release_data)
    release_data['arm_board']
  end

  def arch_by_release(release_data)
    release_data['arch']
  end

  def components_by_release(release_data)
    release_data['components']
  end

  def release_types
    data['release_types'].keys
  end

  def releases_for_type(type)
    data['release_types'].fetch(type)['releases'].keys.to_a
  end

  def release_data_for_type(type)
    data['release_types'].fetch(type)['releases']
  end

  def get_release_data(type, release)
    @release_data = release_data_for_type(type)[release].to_h
  end
end
