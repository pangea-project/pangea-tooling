require 'json'
require 'pathname'
require 'uri'
require 'fileutils'

require_relative 'ci/upstream_scm'
require_relative 'debian/control'
require_relative 'debian/source'

require_relative 'deprecate'

# A thing that gets built.
class Project
  class Error < Exception; end
  # FIXME: this should maybe drop git to also fit bzr
  class GitTransactionError < Error; end

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
  # TODO: drop _scm_scm
  alias_method :packaging_scm_scm, :packaging_scm
  deprecate :packaging_scm_scm, :packaging_scm, 2016, 01

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
                 branch: "kubuntu_#{type}")
    variable_deprecation(:type, :branch) unless type.nil?
    @name = name
    @component = component
    @upstream_scm = nil
    @provided_binaries = []
    @dependencies = []
    @dependees = []
    @series_branches = []
    @autopkgtest = false

    # Jenkins doesn't like slashes. Nor should it have to, any sort of ordering
    # would be the result of component/name, which is precisely why neither must
    # contain additional slashes as then they'd be $pathtype/$pathtype which
    # often will need different code (mkpath vs. mkdir).
    if @name.include?('/')
      fail NameError, "name value contains a slash: #{@name}"
    end
    if @component.include?('/')
      fail NameError, "component contains a slash: #{@component}"
    end

    # FIXME: git dir needs to be set somewhere, somehow, somewhat, lol, kittens?
    if component == 'launchpad'
      packaging_scm_url = if url_base.end_with?(':')
                            "#{url_base}#{name}"
                          else
                            "#{url_base}/#{name}"
                          end
      @packaging_scm = CI::SCM.new('bzr', packaging_scm_url)
      FileUtils.mkdir_p('launchpad') unless Dir.exist?('launchpad')
      component_dir = 'launchpad'
    else
      # Assume git
      # Clean up path to remove useless slashes and colons.
      packaging_scm_url =
        Project.cleanup_uri("#{url_base}/#{component}/#{name}")
      @packaging_scm = CI::SCM.new('git', packaging_scm_url, branch)
      component_dir = "git/#{component}"
      FileUtils.mkdir_p(component_dir) unless Dir.exist?(component_dir)
    end
    Dir.chdir(component_dir) do
      get
      Dir.chdir(name) do
        update(branch)

        next unless File.exist?('debian/control')

        c = DebianControl.new
        # TODO: raise? return?
        c.parse!

        %w(build-depends build-depends-indep).each do |field|
          c.source.fetch(field, []).each do |dep|
            @dependencies << dep.name
          end
        end

        c.binaries.each do |binary|
          @provided_binaries << binary['package']
        end

        # FIXME: Probably should be converted to a symbol at a later point
        #        since xs-testsuite could change to random other string in the
        #        future
        @autopkgtest = c.source['xs-testsuite'] == 'autopkgtest'
      end
    end
  end

  def self.cleanup_uri(uri)
    uri = URI(uri) unless uri.is_a?(URI)
    uri.path = Pathname.new(uri.path).cleanpath.to_s
    uri.to_s
  end

  # @param uri <String> uri of the repo to clone
  # @param dest <String> directory name of the dir to clone as
  def get_git(uri, dest)
    return if File.exist?(dest)
    5.times do
      break if system("git clone #{uri} #{dest}", err: '/dev/null')
    end
    fail GitTransactionError, "Could not clone #{uri}" unless File.exist?(dest)
  end

  def update_git
    system('git clean -fd')
    system('git reset --hard')

    i = 0
    while (i += 1) < 5
      system('git gc')
      system('git config remote.origin.prune true')
      break if system('git pull', err: '/dev/null')
    end
    fail GitTransactionError, 'Failed to pull' if i >= 5
  end

  # @see {get_git}
  def get_bzr(uri, dest)
    return if File.exist?(dest)
    5.times do
      break if system("bzr branch #{uri} #{dest}")
    end
    fail GitTransactionError, "Could not clone #{uri}" unless File.exist?(dest)
  end

  def update_bzr
    system('bzr pull')
  end

  def get
    if @component == 'launchpad'
      get_bzr(@packaging_scm.url, @name)
    else
      get_git(@packaging_scm.url, @name)
    end
  end

  def update(branch)
    if @component == 'launchpad'
      update_bzr
    else
      update_git

      # FIXME: bzr has no concept of branches?
      unless system("git checkout #{branch}")
        fail GitTransactionError, "No branch #{branch}"
      end

      branches = `git for-each-ref --format='%(refname)' refs/remotes/origin/#{branch}_\*`.strip.lines
      branches.each do |b|
        @series_branches << b.gsub('refs/remotes/origin/', '')
      end
      unless Debian::Source.new(Dir.pwd).format.type == :native
        @upstream_scm = CI::UpstreamSCM.new(@packaging_scm.url, branch)
      end
    end
  end
end

# @private
class ProjectFactory
  def self.find_all_repos(searchpath, hostcmd: 'ssh git.debian.org')
    # This uses a command argument so we can test this in a way that bypasses
    # ssh entirely. Otherwise the test would require a working SSH setup.
    # Should this become a problem in the future we need a way to somehow force
    # A different command. e.g. invidual classes SSHListing LocalListing
    # where former probably derives from latter as to get very close testing
    # coverage.
    output = `#{hostcmd} find #{searchpath} -maxdepth 1 -type d`
    fail 'Failed to find repo list on host' unless $? == 0
    output.chop.split(' ')
  end

  def self.split_find_output(output)
    output.collect! { |path| File.basename(path).gsub!('.git', '') }
    output.uniq!
    output.compact!
    output
  end

  def list_all_repos(component)
    searchpath = "/git/pkg-kde/#{component}/"
    output = self.class.find_all_repos(searchpath)
    self.class.split_find_output(output)
  end

  def factorize(key, value, type)
    ret = []
    case key
    when 'all_repos'
      value.each do |component|
        repos = list_all_repos(component)
        repos.each do |name|
          begin
            ret << Project.new(name, component, type: type)
          rescue Project::Error
          end
        end
      end
    when 'selective_repos'
      value.each do |component, names|
        names.each do |name|
          begin
            ret << Project.new(name, component, type: type)
          rescue Project::Error
          end
        end
      end
    when 'selective_exlusion'
      value.each do |component, blacklist|
        repos = list_all_repos(component)
        repos.each do |name|
          begin
            unless blacklist.include?(name)
              ret << Project.new(name, component, type: type)
            end
          rescue Project::Error
          end
        end
      end
    when 'custom_ci'
      # I do so hate my life.
      # In custom_ci:
      #  - type [String](optional) a unique identifier naming a special handling
      #      type which will run before general handling and can attempt to
      #      produce a repos array to construct. If it fails to do so general
      #      handling kicks in.
      #  - git_host [String](optional) a URL base for the repos
      #      (e.g. git://localhost/)
      #  - org [String](optional) the component to look for repos under.
      #      Unless special type handling is used org is equal to a
      #      #{Project.component}, it will be used in urls base/comp/name and
      #      usually act as grouping identifier for projects.
      #      Must not contain slashes!
      #  - repos [Array<String>] an array of repo names to create Project
      #      instances for. These repos will be looked for in a directory 'org'
      #      and cached in a directory 'org'. The Strings are roughly equal to
      #      #{Project.name}.
      #      Special array constructs are possible but dependent on special
      #      handling types.
      #      Must not contain slashes!

      value.each do |custom_ci|
        repos = []
        # Special type handling.
        case custom_ci['type']
        when 'github'
          require 'octokit'
          custom_ci['git_host'] = 'https://github.com/'
          if custom_ci['repos'] == ['all']
            octo_repos = Octokit.organization_repositories(custom_ci['org'])
            octo_repos.each do |octo_repo|
              repos << octo_repo[:name]
            end
          end
        end
        # Ultimate fallback if special type handling failed to produce repos.
        repos = custom_ci['repos'] if repos.empty?
        fail if repos.empty? # Shouldn't be empty here. Must be something wrong
        # Create actual Project instances.
        repos.each do |repo|
          # FIXME: why the fucking fuck is the component field called org
          #   what the fuck.
          ret << Project.new(repo,
                             custom_ci['org'] || '',
                             custom_ci['git_host'],
                             type: type)
        end
      end
    when 'static_ci'
      value.each do |static_ci|
        unless static_ci['type'] == 'debian' ||
               static_ci['type'] == 'neon'
          fail "Unknown type #{static_ci['type']}"
        end
        repos = static_ci['repos'].collect { |e| p OpenStruct.new(e) }
        repos.each do |repo|
          repo_path_parts = repo.path.split('/')
          name = repo_path_parts.pop
          component = repo_path_parts.pop || ''
          git_path = repo_path_parts.pop || ''
          case static_ci['type']
          when 'neon'
            # FIXME: fekking hardcoded url
            pro = Project.new(name, component,
                              "git://packaging.neon.kde.org.uk/#{git_path}",
                              branch: repo.branch)
          when 'debian'
            git_path = "#{Project.default_url.gsub('/pkg-kde', '')}/#{git_path}"
            pro = Project.new(name, component,
                              git_path,
                              branch: repo.branch)
          end
          pro.upstream_scm = CI::SCM.new('tarball', URI.decode(repo.tarball))
          ret << pro
        end
      end
    when 'launchpad'
      value.each do |launchpad|
        repos = launchpad['repos']
        repos.each do |repo|
          name = repo.split('/')[-1]
          uri_base = repo.split('/')[0..-2].join('/').prepend('lp:')
          pro = Project.new(name, 'launchpad', uri_base)
          ret << pro
        end
      end
    else
      fail "ProjectFactory encountered an unknown configuration key: #{key}"
    end
    ret
  end
end

class Projects < Array
  def initialize(type: 'unstable',
                 allow_custom_ci: false,
                 projects_file: File.expand_path(File.dirname(File.dirname(__FILE__))) + '/data/projects.json')
    super()
    config = JSON.parse(File.read(projects_file))
    config.delete('custom_ci') unless allow_custom_ci

    config.each do |key, value|
      concat(ProjectFactory.new.factorize(key, value, type))
    end

    # Build a hash for quick lookup of which source provides which binary.
    provided_by = {}
    each do |project|
      project.provided_binaries.each do |binary|
        provided_by[binary] = project.name
      end
    end

    self.collect! do |project|
      project.dependencies.collect! do |dependency|
        next unless provided_by.include?(dependency)
        dependency = provided_by[dependency]
        # Reverse insert us into the list of dependees of our dependency
        self.collect! do |dep_project|
          next dep_project if dep_project.name != dependency
          dep_project.dependees << project.name
          dep_project.dependees.compact!
          break dep_project
        end
        next dependency
      end
      # Ditch nil and duplicates
      project.dependencies.compact!
      project
    end
  end
end
