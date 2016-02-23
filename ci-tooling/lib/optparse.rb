# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require 'optparse'

# Patched option parser to support missing method checks.
# @example Usage
#   parser = OptionParser.new do |opts|
#     opts.on('-l', '--long LONG', 'expected long', 'EXPECTED') do |v|
#     end
#   end
#   parser.parse!
#
#   unless parser.missing_expected.empty?
#     puts "Missing expected arguments: #{parser.missing_expected.join(', ')}"
#     abort parser.help
#   end
class OptionParser
  # @!attribute [r] missing_expected
  #   @return [Array<String>] the list of missing options; long preferred.
  def missing_expected
    @missing_expected ||= []
  end

  # @!visibility private
  alias super_make_switch make_switch

  # @!visibility private
  # Decided whether an expected arg is present depending on whether it is in
  # default_argv. This is slightly naughty since it processes them out of order.
  # Alas, we don't usually parse >1 time and even if so we care about both
  # anyway.
  def make_switch(opts, block = nil)
    switches = super_make_switch(opts, block)

    return switches unless opts.delete('EXPECTED')

    switch = switches[0] # >0 are actually parsed versions
    short = switch.short
    long = switch.long
    unless present?(short, long)
      missing_expected
      @missing_expected << long[0] ? long[0] : short[0]
    end
    switches
  end

  private

  def present?(short, long)
    short_present = short.any? { |s| default_argv.include?(s) }
    long_present = long.any? { |l| default_argv.include?(l) }
    short_present || long_present
  end
end
