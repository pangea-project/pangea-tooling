require 'pathname'

module CI
  # Helper class for direct bindings.
  # Direct bindings are simply put absolute paths on the host that are meant
  # to be 1:1 bound into a container. Binding into a container requires the
  # definition of a volume and the actual binding map, both use a different
  # format and are more complex than a simple linear array of paths.
  # DirectBindingArray helps with converting a linear array of paths into
  # the respective types Docker expects.
  class DirectBindingArray
    class ExcessColonError < Exception; end

    # @return [Hash] Volume API hash of the form { Path => {} }
    def self.to_volumes(array)
      array.each_with_object({}) do |bind, memo|
        volume_specification_check(bind)
        memo[bind.split(':').first] = {}
      end.to_h
    end

    # @return [Array] Binds API array of the form ["Path:Path"]
    def self.to_bindings(array)
      array.collect do |bind|
        volume_specification_check(bind)
        next bind if mapped?(bind)
        "#{bind}:#{bind}"
      end
    end

    def self.volume_specification_check(str)
      if str.count(':') > 1
        raise ExcessColonError, 'Invalid docker volume notation'
      end
    end

    # Helper for binding candidates with colons.
    # Bindings are a bit tricky as we want to support explicit bindings AND
    # flat paths that get 1:1 mapped into the container.
    # i.e.
    #   /tmp:/tmp
    #      is a binding map already
    #   /tmp/CI::ABC
    #      is not and we'll want to 1:1 bind.
    # To tell the two apart we check if the first character after the colon
    # is a slash (target paths need to be absolute). This is fairly accurate
    # but a bit naughty code-wise, unfortunately the best algorithmic choice
    # we appear to have as paths can generally contain : all over the place.
    # Ultimately this is a design flaw in the string based mapping in Docker's
    # API really.
    def self.mapped?(bind)
      parts = bind.split(':')
      return false if parts.size <= 1
      parts.shift
      Pathname.new(parts.join(':')).absolute?
    end
  end
end
