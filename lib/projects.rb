# frozen_string_literal: true

# SPDX-FileCopyrightText: 2014-2020 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2014-2016 Rohan Garg <rohan@garg.io>
# SPDX-FileCopyrightText: 2015 Jonathan Riddell <jr@jriddell.org>
# SPDX-FileCopyrightText: 2015 Bhushan Shah <bshah@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'concurrent'
require 'fileutils'
require 'forwardable' # For cleanup_uri delegation
require 'git_clone_url'
require 'json'
require 'rugged'
require 'net/ssh'

require_relative 'ci/overrides'
require_relative 'ci/upstream_scm'
require_relative 'debian/control'
require_relative 'debian/source'
require_relative 'debian/relationship'
require_relative 'retry'
require_relative 'kdeproject_component'

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
  class ShitPileErrror < RuntimeError; end
  # Override expectation makes no sense. The member is nil.
  class OverrideNilError < RuntimeError
    def initialize(component, name, member, value)
      super(<<~ERR)
        There is an override for @#{member} to "#{value}"
        in project "#{name}", component "#{component}"
        but that member is nil. Members which are nil cannot be overridden
        as nil is considered a final state. e.g. a nil @upstream_scm means
        the source is native so it would not make sense to set a
        source as it would not be used. Check your conditions!
      ERR
    end
  end

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
        @cache ||= Concurrent::Array.new
      end
    end
  end

  extend Deprecate

  # Name of the thing (e.g. the repo name)
  attr_reader :name
  # Super component (e.g. plasma)
  attr_reader :component
  # KDE component (e.g. frameworks, plasma, release_service, extragear)
  attr_reader :kdecomponent
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

  # Path to snapcraft.yaml if any
  attr_reader :snapcraft

  # Whether the project has debian packaging
  attr_reader :debian
  alias debian? debian

  # List of dist ids that this project is restricted to (e.g. %w[xenial bionic focal]
  # should prevent the project from being used to create jobs for `artful`)
  # This actually taking effect depends on the specific job/project_updater
  # implementation correctly implementing the restriction.
  attr_reader :series_restrictions

  DEFAULT_URL = 'git.debian.org:/git/pkg-kde'
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
    @debian = false
    @series_restrictions = []
    @kdecomponent = if KDEProjectsComponent.frameworks_jobs.include?(name)
                      'frameworks'
                    elsif KDEProjectsComponent.release_service_jobs.include?(name)
                      'release_service'
                    elsif KDEProjectsComponent.plasma_jobs.include?(name)
                      'plasma'
                    else
                      'extragear'
                    end

    if component == 'kde-extras_kde-telepathy'
      puts 'stepped into a shit pile --> https://phabricator.kde.org/T4160'
      raise ShitPileErrror,
            'stepped into a shit pile --> https://phabricator.kde.org/T4160'
    end

    # FIXME: this should run at the end. test currently assume it isn't though
    validate!

    init_packaging_scm(url_base, branch)
    cache_dir = cache_path_from(packaging_scm)

    @override_rule = CI::Overrides.new.rules_for_scm(@packaging_scm)
    override_apply('packaging_scm')

    get(cache_dir)
    update(branch, cache_dir)
    Dir.mktmpdir do |checkout_dir|
      checkout(branch, cache_dir, checkout_dir)
      init_from_source(checkout_dir)
    end

    @override_rule.each do |member, _|
      override_apply(member)
    end

    # Qt6 Hack
    if name == 'qt6'
      upstream_scm.instance_variable_set(:@type, 'uscan')
      return
    end

    upstream_scm&.releaseme_adjust!(origin)
  end

  def packaging_scm_for(series:)
    # TODO: it'd be better if this was somehow tied into the SCM object itself.
    #   Notably the SCM could ls-remote and build a list of all branches on
    #   remote programatically. Then we carry that info in the SCM, not the
    #   project.
    #   Doesn't really impact the code here though. The SCM ought to still be
    #   unaware of the code branching.
    branch = series_branches.find { |b| b.split('_')[-1] == series }
    return packaging_scm unless branch

    CI::SCM.new(packaging_scm.type, packaging_scm.url, branch)
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

  def init_from_debian_source(dir)
    return unless File.exist?("#{dir}/debian/control")

    control = Debian::Control.new(dir)
    # TODO: raise? return?
    control.parse!
    init_from_control(control)
    # Unset previously default SCM
    @upstream_scm = nil if native?(dir)
    @debian = true
  rescue => e
    raise e.exception("#{e.message}\nWhile working on #{dir}/debian -- #{name}")
  end

  def init_from_source(dir)
    @upstream_scm = CI::UpstreamSCM.new(@packaging_scm.url,
                                        @packaging_scm.branch)
    @snapcraft = find_snapcraft(dir)
    init_from_debian_source(dir)
    # NOTE: assumption is that launchpad always is native even when
    #  otherwise noted in packaging. This is somewhat meh and probably
    #  should be looked into at some point.
    #  Primary motivation are compound UDD branches as well as shit
    #  packages that are dpkg-source v1...
    @upstream_scm = nil if component == 'launchpad'
  end

  def find_snapcraft(dir)
    file = Dir.glob("#{dir}/**/snapcraft.yaml")[0]
    return file unless file

    Pathname.new(file).relative_path_from(Pathname.new(dir)).to_s
  end

  def native?(directory)
    return false if Debian::Source.new(directory).format.type != :native

    blacklist = %w[release_service frameworks plasma kde-extras]
    return true unless blacklist.include?(component)

    # NOTE: this is a bit broad in scope, may be more prudent to have the
    #   factory handle this after collecting all promises.
    raise <<-ERROR
#{name} is in #{component} and marked native. Projects in that component
absolutely must not be native though!
    ERROR
  end

  def init_deps_from_control(control)
    fields = %w[build-depends]
    # Do not cover indep for Qt because Qt packages have a dep loop in them.
    unless control.source.fetch('Source', '').include?('-opensource-src')
      fields << 'build-depends-indep'
    end
    fields.each do |field|
      control.source.fetch(field, []).each do |alt_deps|
        alt_deps = alt_deps.select do |relationship|
          relationship.applicable_to_profile?(nil)
        end
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
    @override_rule[member]
  end

  def override_applicable?(member)
    return false unless @override_rule

    # Overrides are cascading so a more general rule could conflict with a more
    # specific one. In that event manually setting the specific one to nil
    # should be passing as no-op.
    # e.g. all Neon/releases are forced to use uscan. That would fail the
    # validation below, so native software would then explicit set
    # upstream_scm:nil in their specific override. This then triggers equallity
    # which we consider no-op.
    if override_rule_for(member) == instance_variable_get("@#{member}")
      return false
    end

    unless instance_variable_get("@#{member}")
      raise OverrideNilError.new(@component, @name, member, override_rule_for(member)) if override_rule_for(member)

      return false
    end

    return false unless @override_rule.include?(member)

    true
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
    return unless override_applicable?(member)

    object = instance_variable_get("@#{member}")
    rule = override_rule_for(member)
    unless rule
      instance_variable_set("@#{member}", nil)
      return
    end

    # If the rule isn't as hash we can simply apply it as member object.
    # This is for example enabling us to override arrays of strings etc.
    unless rule.is_a?(Hash)
      instance_variable_set("@#{member}", rule.dup)
      return
    end

    # Otherwise the rule is a hash and we'll apply its valus to the object
    # instead. This is not applying properties any deeper!
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
    def git_credentials(url, username, types)
      config = Net::SSH::Config.for(GitCloneUrl.parse(url).host)
      default_key = "#{Dir.home}/.ssh/id_rsa"
      key = File.expand_path(config.fetch(:keys, [default_key])[0])
      p credentials = Rugged::Credentials::SshKey.new(
        username: username,
        publickey: key + '.pub',
        privatekey: key,
        passphrase: ''
      )
      credentials
    end

    # @param uri <String> uri of the repo to clone
    # @param dest <String> directory name of the dir to clone as
    def get_git(uri, dest)
      return if File.exist?(dest)

      if URI.parse(uri).scheme == 'ssh'
        Rugged::Repository.clone_at(uri, dest,
                                    bare: true,
                                    credentials: method(:git_credentials))
      else
        Rugged::Repository.clone_at(uri, dest, bare: true)
      end

    rescue Rugged::NetworkError => e
      p uri
      raise GitTransactionError, e
    end

    # @see {get_git}
    def get_bzr(uri, dest)
      return if File.exist?(dest)
      return if system("bzr checkout --lightweight #{uri} #{dest}")

      raise BzrTransactionError, "Could not checkout #{uri}"
    end

    def update_git(dir)
      return unless VCSCache.update?(dir)

      # TODO: should change to .bare as its faster. also in checkout.
      repo = Rugged::Repository.new(dir)
      repo.config.store('remote.origin.prune', true)
      repo.remotes['origin'].fetch
    rescue Rugged::NetworkError => e
      raise GitTransactionError,
            "Failed to update git clone of #{packaging_scm.url}: #{e}"
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
  end

  def schemeless_path(url)
    return url if url[0] == '/' # Seems to be an absolute path already!

    uri = GitCloneUrl.parse(url)
    uri.scheme = nil
    path = uri.to_s
    path = path[1..-1] while path[0] == '/'
    path
  end

  def cache_path_from(scm)
    path = schemeless_path(scm.url)
    raise "couldnt build cache path from #{uri}" if path.empty?

    path = File.absolute_path("cache/projects/#{path}")
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir, verbose: true) unless Dir.exist?(dir)
    path
  end

  def init_packaging_scm_bzr(url_base)
    packaging_scm_url = if url_base.end_with?(':')
                          "#{url_base}#{@name}"
                        else
                          "#{url_base}/#{@name}"
                        end
    @packaging_scm = CI::SCM.new('bzr', packaging_scm_url)
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

        # NB: this is used for per-series mutation when neon is moving
        #   from one to another series. The branch gets recorded here
        #   and the job templates then figure out what branch to use by calling
        #   #packaging_scm_for
        branches = `cd #{dir} && git for-each-ref --format='%(refname)' refs/remotes/origin/#{branch}_\*`.strip.lines
        branches.each do |b|
          @series_branches << b.gsub('refs/remotes/origin/', '').strip
        end
      end
    end
  end

  def checkout_lp(cache_dir, checkout_dir)
    FileUtils.rm_r(checkout_dir, verbose: true)
    FileUtils.ln_s(cache_dir, checkout_dir, verbose: true)
  end

  def checkout_git(branch, cache_dir, checkout_dir)
    repo = Rugged::Repository.new(cache_dir)
    repo.workdir = checkout_dir
    b = "origin/#{branch}"
    branches = repo.branches.each_name.to_a
    unless branches.include?(b)
      raise GitNoBranchError, "No branch #{b} for #{name} found #{branches}"
    end

    repo.reset(b, :hard)
  end

  def checkout(branch, cache_dir, checkout_dir, series: false)
    # This meth cannot have transaction errors as there is no network IO going
    # on here.
    return checkout_lp(cache_dir, checkout_dir) if @component == 'launchpad'

    checkout_git(branch, cache_dir, checkout_dir)
  rescue Project::GitNoBranchError => e
    raise e if series || !branch.start_with?('Neon/')

    # NB: this is only used for building of the dependency list and the like.
    # The actual target branches are picked from the series_branches at
    # job templating time, much later. This order only represents our
    # preference for dep data (they'll generally only vary in minor degress
    # between the various branches).
    # Secondly we want to raise back into the factory if they asked us to
    # construct a project for branch Neon/unstable but no such branch and no
    # series variant of it exists.
    require_relative 'nci'
    new_branch = @series_branches.find { |x| x.end_with?(NCI.current_series) }
    if NCI.future_series && !new_branch
      new_branch = @series_branches.find { |x| x.end_with?(NCI.future_series) }
    end
    if NCI.old_series && !new_branch
      new_branch = @series_branches.find { |x| x.end_with?(NCI.old_series) }
    end
    raise e unless new_branch

    warn "Failed to find branch #{branch}; falling back to #{new_branch}"
    checkout(new_branch, cache_dir, checkout_dir, series: true)
  end

  def inspect
    vset = instance_variables[0..4]
    str = "<#{self.class}:#{object_id} "
    str += vset.collect do |v|
      value = instance_variable_get(v)
      # Prevent infinite recursion in case there's a loop in our
      # dependency members.
      inspection = if value.is_a?(Array) && value[0]&.is_a?(self.class)
                     'ArrayOfNestedProjects'
                   else
                     value.inspect
                   end
      "#{v}=#{inspection}"
    end.compact.join(', ')
    str += '>'

    str
  end
end
