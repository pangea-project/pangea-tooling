# frozen_string_literal: true
require_relative 'xci'

# BS-specific Xenon CI
module XenonCI
  extend XCI

  module_function
  def architectures_for_type
    data['architectures_for_type']
  end
end
