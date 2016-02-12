module Debian
  # A debian policy version handling class.
  class Version
    attr_reader :full
    attr_reader :epoch
    attr_reader :upstream
    attr_reader :revision

    def initialize(string)
      @full = string
      @epoch = nil
      @upstream = nil
      @revision = nil
      parse
    end

    def to_s
      @full
    end

    private

    def parse
      regex = /^(?:(?<epoch>\d+):)?
                (?<upstream>[A-Za-z0-9.+:~-]+?)
                (?:-(?<revision>[A-Za-z0-9.~+]+))?$/x
      match = @full.match(regex)
      @epoch = match[:epoch]
      @upstream = match[:upstream]
      @revision = match[:revision]
    end
  end
end
