module Debian
  class Architecture
    attr_accessor :arch

    def initialize(arch)
      @arch = arch
      @has_modifier = @arch.start_with?('!')
    end

    def qualify?(other)
      other_has_modifier = other.start_with?('!')
      other = other.delete('!')
      arch = @arch.delete('!')

      success = system("dpkg-architecture -a #{arch} -i #{other} -f")
      result = other_has_modifier ^ @has_modifier ? !success : success
      result
    end
  end
end
