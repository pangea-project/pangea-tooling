module Deprecate
  include Gem::Deprecate

  def self.extended(othermod)
    othermod.send :include, InstanceMethods
    super(othermod)
  end

  module InstanceMethods
    def variable_deprecation(variable, repl = :none)
      klass = self.is_a? Module
      target = klass ? "#{self}." : "#{self.class}#"
      meth = caller_locations(1, 1)[0].label
      msg = [
        "NOTE: Variable '#{variable}' in #{target}#{meth} is deprecated",
        repl == :none ? ' with no replacement' : "; use '#{repl}' instead",
        "\n'#{variable}' used around #{Gem.location_of_caller.join(":")}"
      ]
      warn "#{msg.join}." unless Gem::Deprecate.skip
    end
  end
end
