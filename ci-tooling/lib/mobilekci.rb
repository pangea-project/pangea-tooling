# frozen_string_literal: true
require_relative 'xci'

# Plasma Mobile Kubuntu CI specific data.
module MCI
  extend XCI
  module_function
  def architectures_for_device
    data['architectures_for_device']
  end

  def devices
    data['devices']
  end
end
