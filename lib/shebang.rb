class Shebang
  attr_reader :valid
  attr_reader :parser

  def initialize(line)
    @valid = false
    @parser = nil

    return unless line
    return unless line.start_with?('#!')

    parts = line.split(' ')

    return unless parts.size >= 1
    if parts[0].end_with?('/env')
      return unless parts.size >= 2
      @parser = parts[1]
    elsif !parts[0].include?('/') || parts[0].end_with?('/')
      return # invalid
    else
      @parser = parts[0].split('/').pop
    end

    @valid = true
  end
end
