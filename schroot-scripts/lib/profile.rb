require 'erb'
require 'fileutils'

class SchrootProfile
  attr_reader :name
  attr_reader :series
  attr_reader :arch
  attr_reader :description
  attr_reader :directory
  attr_reader :users
  attr_reader :workspace
  attr_reader :tooling

  def initialize(name:, series:, arch:, directory:, users:, workspace:)
    @name = name
    @series = series
    @arch = arch
    @description = "#{name} (#{series}/#{arch})"
    @directory = directory
    @users = users.join(',')
    @workspace = workspace
    # FIXME: should probably in a higher level class
    @tooling = '/var/lib/jenkins/tooling/imager'
  end

  def deploy_profile(template_path, target_path)
    FileUtils.mkpath(target_path)
    FileUtils.cp_r(Dir["#{template_path}/*"], target_path)
    Dir.glob("#{target_path}/**/**").each do |file|
      next if File.directory?(file)
      File.write(file, render(file))
    end
  end

  def deploy_config(template_path, target_path)
    if File.directory?(target_path)
      target_path = File.join(target_path, File.basename(template_path))
    end
    File.write(target_path, render(template_path))
  end

  def rewire_config(config_path)
    lines = File.read(config_path).lines
    fail 'last line is a newline' if lines.last == "\n"
    lines << "profile=#{name}\n"
    File.write(config_path, lines.join(''))
  end

  def render(path)
    data = File.read(path)
    ERB.new(data).result(binding)
  end
end
