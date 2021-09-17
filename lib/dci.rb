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
    return true if rel.end_with?('c1' || 'rock64')
  end

  def arm_board_by_release(release)
    arm_boards.each do | board |
      if release.end_with? board
        return board
      else
        "This is not arm, something has gone wrong."
      end
    end
  end

  def release_types
    data['release_types'].keys
  end

  def releases_for_type(type)
    data['release_types'].fetch(type).fetch('releases').keys
  end

  def release_data_for_type(type)
    typedata = data['release_types'].fetch(type).fetch('releases')
    typedata
  end

  def get_release_data(type, release)
    @release_data = release_data_for_type(type)[release].to_h
  end
end
