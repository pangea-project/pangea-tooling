# frozen_string_literal: true
require_relative 'xci'

# Debian CI specific data.
module DCI
  extend XCI

  module_function

  def arm_boards
    #To define which board we are building on in ARM jobs..
    data['arm_boards']
  end

  def architecture
    data['architecture']
  end

end
