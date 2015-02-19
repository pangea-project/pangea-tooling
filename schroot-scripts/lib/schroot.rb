require 'fileutils'

require_relative 'profile'

class Schroot
  CHROOT_DIR = '/srv/chroot'

  CONF_DIR = '/etc/schroot'
  CONF_CHROOT_DIR = '/etc/schroot/chroot.d'

  JENKINS_DIR = '/var/lib/jenkins'
  JENKINS_TOOLING = "#{JENKINS_DIR}/tooling/imager"

  attr_reader :chroot_name
  attr_reader :chroot_dir

  def initialize(stability:, series:, arch:)
    @stability = stability
    @series = series
    @arch = arch

    @name = 'jenkins-imager'
    @chroot_name = "#{@name}-#{@series}-#{@stability}-#{@arch}"
    @chroot_dir = "#{CHROOT_DIR}/#{@chroot_name}"

    @root_users = %w(apachelogger shadeslayer)
    @mirror = 'http://127.0.0.1:3142/archive.ubuntu.com/ubuntu/'

    # FIXME: maybe should come from job itself? maybe this should only be called from job
    @workspace = "#{JENKINS_DIR}/workspaces/#{@series}/#{@stability}/imager-#{arch}"

    FileUtils.mkpath(CONF_DIR)
    FileUtils.mkpath(CONF_CHROOT_DIR)
  end

  def create
    debootstrap
    # FIXME: the amount of forwarding is all sorts of meh!
    @profile = SchrootProfile.new(name: @chroot_name,
                                  series: @series,
                                  arch: @arch,
                                  directory: @chroot_dir,
                                  users: @root_users,
                                  workspace: @workspace)
    @profile.deploy_config(data_path('config'),
                           "#{CONF_CHROOT_DIR}/#{@chroot_name}")
    write_setup
    run_setup
    @profile.deploy_profile(data_path('profile'), "#{CONF_DIR}/#{@chroot_name}")
    @profile.rewire_config("#{CONF_CHROOT_DIR}/#{@chroot_name}")
  end

  private

  def data_path(name)
    "#{File.expand_path(File.dirname(__FILE__))}/../data/#{name}"
  end

  def debootstrap
    args = []
    args << "--arch=#{@arch}"
    args << '--components=main,restricted,universe,multiverse'
    args << @series
    args << @chroot_dir
    args << @mirror
    fail 'failed to debootstrap' unless system("debootstrap #{args.join(' ')}")
  end

  def write_setup
    FileUtils.mkpath("#{@chroot_dir}/root/")
    FileUtils.cp(data_path('__setup.sh'), "#{@chroot_dir}/root/")
    FileUtils.chmod('+x', "#{@chroot_dir}/root/__setup.sh")
  end

  def run_setup
    args = []
    args << '--chroot' << @chroot_name
    args << '--user' << 'root'
    args << '--directory' << '/root'
    # FIXME: script path needs to be put in a var somewhere
    args << '--' << '/root/__setup.sh'
    fail 'Failed to setup schroot' unless system("schroot #{args.join(' ')}")
    # FIXME: script path needs var
    FileUtils.rm_rf("#{@chroot_dir}/root/__setup.sh")
  end
end
