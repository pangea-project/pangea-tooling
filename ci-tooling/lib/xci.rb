require 'yaml'
require 'ostruct'

# CI specific configuration data.
module XCI
  # @param sort [Symbol] sorting applied to hash
  #   - *:none* No sorting, arbitrary order as in config itself (fastest)
  #   - *:ascending* Oldest version comes first (i.e. [15.04, 15.10])
  #   - *:descending* Oldest version comes last (i.e. [15.10, 15.04])
  # @return [Hash] distribution series
  def series(sort: :none)
    return sort_version_hash(data['series']).to_h if sort == :ascending
    return sort_version_hash(data['series']).reverse.to_h if sort == :descending
    data['series']
  end

  # @return [String] name of the latest (i.e. newest) series
  def latest_series
    @latest_series ||= series(sort: :descending).keys.first
  end

  # Core architectures. These are always enabled architectures that also get
  # ISOs generated and so forth.
  # This for example are general purpose architectures such as i386/amd64.
  # @see .extra_architectures
  # @return [Array<String>] architectures to integrate
  def architectures
    data['architectures']
  end

  # Extra architectures. They differ from core architectures in that they are
  # not automatically enabled and might not be used or useful in all contexts.
  # This for example are special architectures such as ARM.
  # @see .all_architectures
  # @return [Array<String>] architectures to only integrated when explicitly
  #   enabled within the context of a build.
  def extra_architectures
    data['extra_architectures']
  end

  # Convenience function to combine all known architectures. Generally when
  # creating scopes (e.g. when creating jenkins jobs) one wants to use the
  # specific readers as to either use the core architectures or extras or a
  # suitable mix of both. When read-iterating on something that includes the
  # architecture value all_architectures is the way to go to cover all possible
  # architectures.
  # @see .architectures
  # @see .extra_architectures
  # @return [Array<String>] all architectures
  def all_architectures
    architectures + extra_architectures
  end

  # @return [Array<String>] types to integrate (stable/unstable)
  def types
    data['types']
  end

  private

  # @return [Array] array can be converted back with to_h
  def sort_version_hash(hash)
    hash.sort_by { |_, version| Gem::Version.new(version) }
  end

  def data_file_name
    @data_file_name ||= "#{to_s.downcase}.yaml"
  end

  def data_dir
    @data_dir ||= File.join(File.dirname(__dir__), 'data')
  end

  def data_dir=(data_dir)
    reset!
    @data_dir = data_dir
  end

  def data
    return @data if defined?(@data)
    file = File.join(data_dir, data_file_name)
    p file
    fail "Data file not found (#{file})" unless File.exist?(file)
    @data = YAML.load(File.read(file))
  end

  def reset!
    instance_variables.each do |v|
      remove_instance_variable(v)
    end
  end
end
