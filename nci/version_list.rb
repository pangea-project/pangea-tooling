#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2019-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'did_you_mean/spell_checker'
require 'erb'
require 'jenkins_junit_builder'
require 'net/sftp'

require_relative '../lib/kdeproject_component'
require_relative '../lib/aptly-ext/filter'
require_relative '../lib/aptly-ext/package'
require_relative '../lib/aptly-ext/remote'
require_relative 'version_list/violations'

S_IROTH = 0o4 # posix bitmask for world readable

DEBIAN_TO_KDE_NAMES = {
  'attica-kf5' => 'attica',
  'baloo-kf5' => 'baloo',
  'kactivities-kf5' => 'kactivities',
  'kcalcore' => 'kcalendarcore', # fixed in kf6 with kf6-kcalendarcore
  'kdeconnect' => 'kdeconnect-kde',
  'kdevelop-php' => 'kdev-php',
  'kdevelop-python' => 'kdev-python',
  'kdnssd-kf5' => 'kdnssd',
  'kde-spectacle' => 'spectacle',
  'kfilemetadata-kf5' => 'kfilemetadata',
  'kf6-userfeedback'  => 'kf6-kuserfeedback', # why isn't the source name matching the package name??
  'kpim6-incidenceeditor' => 'incidenceeditor',
  'kpim6-pimcommon' => 'pimcommon',
  'kpim6-mailcommon' => 'mailcommon',
  'kpim6-mailimporter' => 'mailimporter',
  'kpim6-calendarsupport' => 'calendarsupport',
  'kpim6-grantleetheme' => 'grantleetheme',
  'kpim6-libkleo' => 'libkleo',
  'kpim6-libkdepim' => 'libkdepim',
  'kpim6-eventviews' => 'eventviews',
  'kpim6-libksieve' => 'libksieve',
  'kpim6-libgravatar' => 'libgravatar',
  'kpim6-messagelib' => 'messagelib',
  'kpim6-libkgapi' => 'libkgapi',
  'kio-extras5' => 'kio-extras-kf5',
  'ksyntax-highlighting' => 'syntax-highlighting',
  'ktp-kded-integration-module' => 'ktp-kded-module',
  'kwallet-kf5' => 'kwallet',
  'libkf5kipi' => 'libkipi',
  'plasma-discover' => 'discover',
  'prison-kf5' => 'prison'
}

# Sources that we do not package for some reason. Should be documented why!
BLACKLIST = [
  'extra-cmake-modules',    # superseded by kf6-extra-cmake-modules
  'breeze-icons',           # superseded by kf6-breeze-icons
  'kactivities',            # superseded by plasma-activities
  'kactivities-stats',      # superseded by plasma-activities-stats
  'kalendar',               # is now merkuno and reports as conflicting with kcalendarcore
  'kf6-kactivities',        # moved to plasma6 as plasma-activities
  'kf6-kactivities-stats',  # moved to plasma6 as plasma-activities-stats
  'kf6-kdelibs4support',    # kde5 framework that was deprecated
  'kf6-kdesignerplugin',    # kde5 framework that was deprecated
  'kf6-kdewebkit',          # kde5 framework that was deprecated
  'kf6-kemoticons',         # kde5 framework that was deprecated
  'kf6-khtml',              # kde5 framework that was deprecated
  'kf6-kinit',              # kde5 framework that was deprecated
  'kf6-kjs',                # kde5 framework that was deprecated
  'kf6-kjsembed',           # kde5 framework that was deprecated
  'kf6-kmediaplayer',       # kde5 framework that was deprecated
  'kf6-plasma-framework',   # moved to plasma6 as libplasma
  'kf6-kross',              # kde5 framework that was deprecated
  'kf6-kwayland',           # moved to plasma6 as kwayland
  'kf6-kxmlrpcclient',      # kde5 framework that was deprecated
  'kfloppy',                # dead project removed in 23.08
  'kopete',                 # dead project removed in 24.02
  'krunner',                # superseded by kf6-krunner
  'libkgapi',               # we package an old version
  'oxygen-icons',           # superseded by kf6-oxygen-icons
  'plasma-framework',       # superseded by libplasma
  'plasma-tests'            # not actually useful for anything in production. It's a repo with tests.
]

# Maps "key" packages to a release scope. This way we can identify what version
# the given scope has in our repo.
KEY_MAPS = {
  'kio' => 'KDE Frameworks 5',
  'kf6-kconfig' => 'KDE Frameworks 6',
  'okular' => 'KDE Gear',
  'plasma-workspace' => 'Plasma by KDE'
}

key_file = ENV.fetch('SSH_KEY_FILE', nil)
ssh_args = key_file ? [{ keys: [key_file] }] : []

product_and_versions = []
# Grab list of all released tarballs
# frameworks needs to before frameworks5, as product_and_versions is a map that we keep adding
# to, so or our tricky tarball product renaming would rename frameworks5 products as well
%w[frameworks frameworks5 release-service plasma].each do |scope|

  dir_path = "stable/#{scope}/"

  # allow for farameworks5 scope not matching directory name
  if scope == 'frameworks5'
    dir_path.gsub!(/5/, '')
  end

  # debug our scope
  puts "processing #{scope} scope"

  Net::SFTP.start('rsync.kde.org', 'ftpneon', *ssh_args) do |sftp|
    if scope == 'frameworks5'
    # narrow scope for frameworks5 directory matching only on 5.* releases
      version_dirs = sftp.dir.glob(dir_path, '5.*')
    else
      version_dirs = sftp.dir.glob(dir_path, '*')
    end
    version_dirs = version_dirs.select(&:directory?)
    version_dirs.select(&:directory?)
    version_dirs = version_dirs.sort_by { |x| Gem::Version.new(x.name) }

    latest = version_dirs[-2..-1].reverse.find do |dir|
      world_readable = ((dir.attributes.permissions & S_IROTH) == S_IROTH)
      warn "Version #{dir.name} of #{scope} has file permissions of #{dir.attributes.permissions}!"
      unless world_readable
        warn "Version #{dir.name} of #{scope} not world readable!" \
          " This will mean that this scope's version isn't checked!"
        next nil
      end
      dir
    end

    unless latest
      raise 'Neither the latest nor the previous version are world readable!' \
          ' Something is astray! This means there are two pending releases???'
    end

    sig_ends = %w[.sig .asc]
    latest_path = "#{dir_path}/#{latest.name}/"
    tars = sftp.dir.glob(latest_path, '**/**')
    tars = tars.select { |x| x.name.include?('.tar.') }
    tars = tars.reject { |x| sig_ends.any? { |s| x.name.end_with?(s) } }

    # collect all our tarballs and map them to product name and version
    product_and_versions += tars.collect do |tar|
      name = File.basename(tar.name) # strip possible subdirs
      match = name.match(/(?<product>[-\w]+)-(?<version>[\d\.]+)\.tar.+/)
      raise "Failed to parse #{name}" unless match
      [match[:product], match[:version]]
    end

    # frameworks need to become kf6-* prefixed to match our package names
    # since there are already 2 scopes with products of the same name but
    # different versions we need to change the kf6 scoped product names
    if scope == 'frameworks'
      product_and_versions.sort.map do |k, v|
        k.gsub!(/\A/,"kf6-")
        # debug our product and versions
        puts "the current scope= #{scope} && product= #{k} && version= #{v}"
      end
    else
      product_and_versions.sort.map do |k, v|
        # debug our product and versions
        puts "the current scope= #{scope} && product= #{k} && version= #{v}"
      end
    end
  end
end

scoped_versions = {}
packaged_versions = {}
violations = []

Aptly::Ext::Remote.neon do
  pub = Aptly::PublishedRepository.list.find do |r|
    r.Prefix == ENV.fetch('TYPE') && r.Distribution == ENV.fetch('DIST')
  end
  pub.Sources.each do |source|
    packages = source.packages(q: '$Architecture (source)')
    packages = packages.collect { |x| Aptly::Ext::Package::Key.from_string(x) }
    by_name = packages.group_by(&:name)

    # map debian names to kde names so we can easily compare things
    by_name = by_name.collect { |k, v| [DEBIAN_TO_KDE_NAMES.fetch(k, k), v] }.to_h

    # Hash the packages by their versions, take the versions and sort them
    # to get the latest available version of the specific package at hand.
    by_name = by_name.map do |name, pkgs|
      by_version = Aptly::Ext::LatestVersionFilter.debian_versions(pkgs)
      versions = by_version.keys
      [name, versions.max.upstream]
    end.to_h
    # by_name is now a hash of package names to upstream versions

    # Extract our scope markers into the output array with a fancy name.
    # This kind of collapses all plasma packages into one Plasma entry for
    # example.
    KEY_MAPS.each do |key_package, pretty_name|
      puts version = by_name[key_package]
      puts scoped_versions[pretty_name] = version
    end

    # The same entity can appear with different versions. Notably that happens
    # when a hotfix is put in the same directory. For example kio 5.74.0 had
    # a bug so 5.74.1 is put in the same dir (even though frameworks usually
    # have no .1 releases).
    # More generally put that means if the same product appears more than once
    # we need to de-duplicate them as hash keys are always unique so the
    # selected version is undefined in that scenario. Given the fact that this
    # can only happen when a product directory contains more than one tarball
    # with the same name but different version we'll adjust the actual
    # expectation to be the strictly greatest version.
    product_and_versions_h = {}
    product_and_versions.map do |k, v|
      product_and_versions_h[k] ||= v
      next if Gem::Version.new(product_and_versions_h[k]) >= Gem::Version.new(v)
      puts product_and_versions_h[k] = v # we found a greater version
    end

    checker = DidYouMean::SpellChecker.new(dictionary: by_name.keys)
    product_and_versions_h.each do |remote_name, remote_version|
      next if BLACKLIST.include?(remote_name) # we don't package some stuff

      puts in_repo = by_name.include?(remote_name)
      unless in_repo
        corrections = checker.correct(remote_name)
        violations << MissingPackageViolation.new(remote_name, corrections)
        next
      end

      # Drop the entry from the packages hash. Since it is part of a scoped
      # release such as plasma it doesn't get listed separately in our
      # output hash.
      repo_version = by_name.delete(remote_name)


      if repo_version != remote_version
        violations <<
          WrongVersionViolation.new(remote_name, remote_version, repo_version)
        next
      end
    end

    packaged_versions = packaged_versions.merge(by_name)

end
end
template = ERB.new(File.read("#{__dir__}/version_list/version_list.html.erb"))
html = template.result(OpenStruct.new(
  scoped_versions: scoped_versions,
  packaged_versions: packaged_versions
).instance_eval { binding })
File.write('versions.html', html)

if violations.empty?
  puts 'All OK!'
  exit 0
end
puts violations.join("\n")

suite = JenkinsJunitBuilder::Suite.new
suite.name = 'version_list'
suite.package = 'version_list'
violations.each do |violation|
  c = JenkinsJunitBuilder::Case.new
  c.name = violation.name
  c.time = 0
  c.classname = violation.class.to_s
  c.result = JenkinsJunitBuilder::Case::RESULT_FAILURE
  c.system_out.message = violation.to_s
  suite.add_case(c)
end
File.write('report.xml', suite.build_report)

exit 1 # had violations
