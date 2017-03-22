# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
# Copyright (C) 2014-2016 Rohan Garg <rohan@garg.io>
# Copyright (C) 2015 Jonathan Riddell <jr@jriddell.org>
# Copyright (C) 2015 Bhushan Shah <bshah@kde.org>
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

require 'fileutils'
require 'forwardable' # For cleanup_uri delegation
require 'json'
require 'rugged'

require_relative 'ci/overrides'
require_relative 'ci/upstream_scm'
require_relative 'debian/control'
require_relative 'debian/source'
require_relative 'retry'

require_relative 'deprecate'

# A thing that gets built.
class Project
  class Error < RuntimeError; end
  class TransactionError < Error; end
  class BzrTransactionError < TransactionError; end
  class GitTransactionError < TransactionError; end
  # Derives from RuntimeError because someone decided to resuce Transaction
  # and Runtime in factories only...
  class GitNoBranchError < RuntimeError; end

  # Caches VCS update runs to not update the same VCS multitple times.
  module VCSCache
    class << self
      # Caches that an update was performed
      def updated(path)
        cache << path
      end

      # @return [Bool] if this path requires updating
      def update?(path)
        return false if ENV.include?('NO_UPDATE')
        !cache.include?(path)
      end

      private

      def cache
        @cache ||= []
      end
    end
  end

  extend Deprecate

  # Name of the thing (e.g. the repo name)
  attr_reader :name
  # Super component (e.g. plasma)
  attr_reader :component
  # Scm instance describing the upstream SCM associated with this project.
  # FIXME: should this really be writable? need this for projects to force
  #        a different scm which is slightly meh
  attr_accessor :upstream_scm
  # Array of binary packages (debs) provided by this project
  attr_reader :provided_binaries

  # Array of package dependencies, initialized by default from control file
  attr_reader :dependencies
  # Array of package dependees, empty Array by default
  attr_reader :dependees

  # Array of branch names that are series specific. May be empty if there are
  # none.
  attr_reader :series_branches

  # Bool whether this project uses autopkgtest
  attr_reader :autopkgtest

  # Packaging SCM instance
  attr_reader :packaging_scm

  DEFAULT_URL = 'git.debian.org:/git/pkg-kde'.freeze
  @default_url = DEFAULT_URL

  class << self
    attr_accessor :default_url
  end

  # Init
  # @param name name of the project (this is equal to the name of the packaging
  #   repo)
  # @param component component within which the project resides (i.e. directory
  #   part of the repo path)
  # @param url_base the base path of the full repo URI. Combined with name and
  #   component this should form a repo URI
  # @param branch branch name in packaging repository to use
  #   branches.
  # @param type the type of integration project (unstable/stable..).
  #   This indicates whether to look for kubuntu_unstable or kubuntu_stable
  #   NB: THIS is mutually exclusive with branch!
  def initialize(name, component, url_base = self.class.default_url,
                 type: nil,
                 branch: "kubuntu_#{type}",
                 origin: CI::UpstreamSCM::Origin::UNSTABLE)
    variable_deprecation(:type, :branch) unless type.nil?
    @name = name
    @component = component
    @upstream_scm = nil
    @provided_binaries = []
    @dependencies = []
    @dependees = []
    @series_branches = []
    @autopkgtest = false

    if component == 'kde-extras_kde-telepathy'
      puts 'stepped into a shit pile --> https://phabricator.kde.org/T4160'
      raise 'stepped into a shit pile --> https://phabricator.kde.org/T4160'
    end

    # FIXME: this should run at the end. test currently assume it isn't though
    validate!

    cache_dir = init_packaging_scm(url_base, branch)
    cache_dir = File.absolute_path("#{cache_dir}/#{name}")

    @override_rule = CI::Overrides.new.rules_for_scm(@packaging_scm)
    override_apply('packaging_scm')

    get(cache_dir)
    update(branch, cache_dir)
    Dir.mktmpdir do |checkout_dir|
      checkout(branch, cache_dir, checkout_dir)
      # FIXME: shouldn't this raise something?
      if File.exist?("#{checkout_dir}/debian/control")
        init_from_source(checkout_dir)
      end
    end

    @override_rule.each do |member, _|
      override_apply(member)
    end

    upstream_scm.releaseme_adjust!(origin) if upstream_scm
  end

  private

  def validate!
    # Jenkins doesn't like slashes. Nor should it have to, any sort of ordering
    # would be the result of component/name, which is precisely why neither must
    # contain additional slashes as then they'd be $pathtype/$pathtype which
    # often will need different code (mkpath vs. mkdir).
    if @name.include?('/')
      raise NameError, "name value contains a slash: #{@name}"
    end
    if @component.include?('/')
      raise NameError, "component contains a slash: #{@component}"
    end
  end

  def init_from_source(directory)
    control = Debian::Control.new(directory)
    # TODO: raise? return?
    control.parse!
    init_from_control(control)

    # NOTE: assumption is that launchpad always is native even when
    #  otherwise noted in packaging. This is somewhat meh and probably
    #  should be looked into at some point.
    #  Primary motivation are compound UDD branches as well as shit
    #  packages that are dpkg-source v1...
    return if @component == 'launchpad'
    return if Debian::Source.new(directory).format.type == :native
    # Set a default upstream_scm.
    @upstream_scm = CI::UpstreamSCM.new(@packaging_scm.url,
                                        @packaging_scm.branch)
  end

  def init_deps_from_control(control)
    fields = %w(build-depends)
    # Do not cover indep for Qt because Qt packages have a dep loop in them.
    unless control.source.fetch('Source', '').include?('-opensource-src')
      fields << 'build-depends-indep'
    end
    fields.each do |field|
      control.source.fetch(field, []).each do |alt_deps|
        @dependencies += alt_deps.collect(&:name)
      end
    end
  end

  def init_from_control(control)
    init_deps_from_control(control)

    control.binaries.each do |binary|
      @provided_binaries << binary['package']
    end

    # FIXME: Probably should be converted to a symbol at a later point
    #        since xs-testsuite could change to random other string in the
    #        future
    @autopkgtest = control.source['xs-testsuite'] == 'autopkgtest'
  end

  def render_override(erb)
    # Versions would be a float. Coerce into string.
    ERB.new(erb.to_s).result(binding)
  end

  def override_rule_for(member)
    @override_rule.delete(member)
  end

  # TODO: this doesn't do deep-application. So we can override attributes of
  #   our instance vars, but not of the instance var's instance vars.
  #   (no use case right now)
  # TODO: when overriding with value nil the thing should be undefined
  # TODO: when overriding with an object that object should be used instead
  #   e.g. when the yaml has one !ruby/object:CI::UpstreamSCM...
  # FIXME: failure not test covered as we cannot supply a broken override
  #   without having one in the live data.
  def override_apply(member)
    return unless @override_rule
    return unless (object = instance_variable_get("@#{member}"))
    return unless @override_rule.include?(member)

    rule = override_rule_for(member)
    unless rule
      instance_variable_set("@#{member}", nil)
      return
    end

    rule.each do |var, value|
      next unless (value = render_override(value))
      # TODO: object.override! can jump in here and do what it wants
      object.instance_variable_set("@#{var}", value)
    end
  rescue => e
    warn "Failed to override #{member} of #{name} with rule #{rule}"
    raise e
  end

  class << self
    # @param uri <String> uri of the repo to clone
    # @param dest <String> directory name of the dir to clone as
    def get_git(uri, dest)
      return if File.exist?(dest)
      Rugged::Repository.clone_at(uri, dest, bare: true)
    rescue Rugged::NetworkError => e
      p e
      raise GitTransactionError, e
    end

    # @see {get_git}
    def get_bzr(uri, dest)
      return if File.exist?(dest)
      return if system("bzr checkout #{uri} #{dest}")
      raise BzrTransactionError, "Could not checkout #{uri}"
    end

    def update_git(dir)
      return unless VCSCache.update?(dir)
      # TODO: should change to .bare as its faster. also in checkout.
      repo = Rugged::Repository.new(dir)
      repo.config.store('remote.origin.prune', true)
      repo.fetch('origin')
    rescue Rugged::NetworkError => e
      raise GitTransactionError, e
    end

    def update_bzr(dir)
      return unless VCSCache.update?(dir)
      return if system('bzr up', chdir: dir)
      raise BzrTransactionError, 'Failed to update'
    end
  end

  def init_packaging_scm_git(url_base, branch)
    # Assume git
    # Clean up path to remove useless slashes and colons.
    @packaging_scm = CI::SCM.new('git',
                                 "#{url_base}/#{@component}/#{@name}",
                                 branch)
    component_dir = "git/#{@component}"
    FileUtils.mkdir_p(component_dir) unless Dir.exist?(component_dir)
    component_dir
  end

  def init_packaging_scm_bzr(url_base)
    packaging_scm_url = if url_base.end_with?(':')
                          "#{url_base}#{@name}"
                        else
                          "#{url_base}/#{@name}"
                        end
    @packaging_scm = CI::SCM.new('bzr', packaging_scm_url)
    component_dir = 'launchpad'
    FileUtils.mkdir_p(component_dir) unless Dir.exist?(component_dir)
    component_dir
  end

  # @return component_dir to use for cloning etc.
  def init_packaging_scm(url_base, branch)
    # FIXME: git dir needs to be set somewhere, somehow, somewhat, lol, kittens?
    if @component == 'launchpad'
      init_packaging_scm_bzr(url_base)
    else
      init_packaging_scm_git(url_base, branch)
    end
  end

  def get(dir)
    Retry.retry_it(errors: [TransactionError], times: 2, sleep: 5) do
      if @component == 'launchpad'
        self.class.get_bzr(@packaging_scm.url, dir)
      else
        self.class.get_git(@packaging_scm.url, dir)
      end
    end
  end

  def update(branch, dir)
    Retry.retry_it(errors: [TransactionError], times: 2, sleep: 5) do
      if @component == 'launchpad'
        self.class.update_bzr(dir)
      else
        self.class.update_git(dir)

        # FIXME: We are not sure this is even useful anymore. It certainly was
        #   not actively used since utopic.
        branches = `cd #{dir} && git for-each-ref --format='%(refname)' refs/remotes/origin/#{branch}_\*`.strip.lines
        branches.each do |b|
          @series_branches << b.gsub('refs/remotes/origin/', '')
        end
      end
    end
  end

  def checkout(branch, cache_dir, checkout_dir)
    # This meth cannot have transaction errors as there is no network IO going
    # on here.
    if @component == 'launchpad'
      FileUtils.rm_r(checkout_dir, verbose: true)
      FileUtils.ln_s(cache_dir, checkout_dir, verbose: true)
    else
      repo = Rugged::Repository.new(cache_dir)
      repo.workdir = checkout_dir
      b = "origin/#{branch}"
      raise GitNoBranchError unless repo.branches.each_name.to_a.include?(b)
      repo.reset(b, :hard)
    end
  end
end
