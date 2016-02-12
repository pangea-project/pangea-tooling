#!/usr/bin/env ruby

require 'fileutils'
require 'open-uri'
require 'tempfile'

require_relative '../lib/debian/changelog'
require_relative '../lib/lp'
require_relative '../lib/retry'

# Publishes a source to launchpad and waits for it to build.
class SourcePublisher
  WAITING_STATES = [
    'Needs building',
    'Currently building',
    'Uploading build',
    'Cancelling build'
  ].freeze
  FAILED_STATES = [
    'Chroot problem',
    'Failed to upload',
    'Failed to build',
    'Build for superseded Source',
    'Cancelled build',
    'Dependency wait'
  ].freeze
  SUCCESS_STATES = ['Successfully built'].freeze

  def initialize(source_name, source_version, ppa = 'unstable')
    @ppa = Launchpad::Rubber.from_path("~kubuntu-ci/+archive/ubuntu/#{ppa}")
    @source_name = source_name
    @source_version = source_version
  end

  def wait
    puts 'Waiting for source to get accepted....'
    # If it takes 30 minutes for the source to arrive it probably got rejected.
    fail_count = 30 # This is ~= minutes

    until source
      sleep(60)
      fail_count -= 1
      if fail_count <= 0
        raise 'Upload was likely rejected, we have been waiting for well' \
             ' over 30 minutes!'
      end
    end

    puts 'Got a source, checking binaries...'

    #################################

    loop do
      sleep_time = 0
      needs_wait = false
      has_failed = false

      source.getBuilds.each do |build|
        state = build.buildstate
        case state
        when *WAITING_STATES
          needs_wait = true
          sleep_time = 60 if sleep_time < 60
        when *FAILED_STATES
          has_failed = true
        when *SUCCESS_STATES
          # all is cool
        else
          raise "Build state '#{build.buildstate}' is not being handled"
        end
      end

      if needs_wait
        sleep(sleep_time)
        next
      end

      if has_failed
        puts 'Got a build failure'
        print_state(source)
        return false
      end

      puts 'Builds look fine, moving on to publication checks'
      break
    end

    sleep(60 * 2) while refresh_source!.status == 'Pending'
    puts 'Soure no longer pending, waiting for binaries...'

    loop do
      has_pending = false
      source_id = File.basename(source.self_link)
      build_summary = @ppa.getBuildSummariesForSourceIds(source_ids: source_id)
      status = build_summary[source_id]['status']
      case status
      when 'FULLYBUILT_PENDING'
        has_pending = true
      when 'FULLYBUILT'
        has_pending = false
      else
        # FIXME: fail?
        puts 'Something very terrible happened as the overall state is' \
             " #{status}, which was not expected at all"
        print_state(get_source)
        return false
      end
      unless has_pending
        puts 'All things are published, hooray!'
        break
      end
      sleep(60)
    end
    puts 'Source published!'

    refresh_source!
    print_state(source)
    get_logs(source)

    puts 'PPA Wait done.'
    true
  end

  private

  def print_state(source)
    puts format('%s/%s (%s) %s',
                source.distro_series.name,
                source.source_package_name,
                source.source_package_version,
                source.status)
    build_logs = {}
    anchor_file = File.open('_anchor-chain', 'w')
    source.getBuilds.each do |build|
      puts format('  %s [%s] (%s) %s :: %s :: %s',
                  source.source_package_name,
                  build.arch_tag,
                  source.source_package_version,
                  build.buildstate,
                  build.web_link,
                  build.build_log_url)
      build_logs[build.arch_tag] = build.build_log_url
      anchor_file.write(format("%s\t%s\n", build.arch_tag, build.build_log_url))
    end
    anchor_file.close

    build_log_marker = 'BUILD -'
    build_logs.each_pair do |arch, log|
      build_log_marker += " [#{arch}] (#{log})"
    end
    puts build_log_marker

    source.getPublishedBinaries.each do |binary|
      puts "    #{binary.display_name} #{binary.status}"
    end
  end

  def get_logs(source)
    puts('getting logs...')

    log_dir = 'logs'
    FileUtils.rm_rf(log_dir)
    Dir.mkdir(log_dir)

    source.getBuilds.each do |build|
      tmpfile = false
      Retry.retry_it(times: 2, sleep: 8) do
        tmpfile = open(build.build_log_url)
      end
      unless tmpfile.is_a?(Tempfile)
        raise IOError, 'open() did not return a Tempfile'
      end
      FileUtils.cp(tmpfile, "#{log_dir}/#{build.arch_tag}.log")
      tmpfile.close

      archindep = source.distro_series.nominatedarchindep.architecture_tag
      File.write('archindep', archindep) if archindep
    end

    puts 'logs done.'
  end

  def source
    return @source if defined?(@source)
    sources = @ppa.getPublishedSources(source_name: @source_name,
                                       version: @source_version,
                                       exact_match: true)
    return nil if sources.size < 1
    if sources.size > 1
      raise "Unexpectedly too many matching sources #{sources}"
    end
    @source = sources[0]
  end

  def refresh_source!
    return unless defined?(@source)
    remove_instance_variable(:@source)
    source
  end
end

if __FILE__ == $PROGRAM_NAME
  _version = '5.4.0'
  # job_name = ARGV[0]
  # ppa_name = ARGV[1]

  # publisher = SourcePublisher.new(changelog.name, changelog.version, ARGV[1])
  publisher = SourcePublisher.new('qtxmlpatterns-opensource-src',
                                  '5.4.0-0ubuntu1~ubuntu14.10~ppa2',
                                  'unstable')
  abort 'PPA Build Failed' unless publisher.wait
  sleep(5)
end
