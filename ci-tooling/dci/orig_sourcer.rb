#!/usr/bin/env ruby

require_relative '../lib/ci/orig_source_builder'
require_relative '../lib/ci/tar_fetcher'

module DCI
  class OrigSourcer
    class << self
      def tarball
        Dir.mkdir('source') unless Dir.exist?('source')
        tarball ||= DCI::OrigSourcer.lookup_tarball
        tarball ||= DCI::OrigSourcer.fetch_url
        tarball ||= DCI::OrigSourcer.fetch_watch
        return tarball if tarball
        raise 'Could not find a tarball'
      end

      def lookup_tarball
        tar = Dir.glob('source/*.tar.*')
        return nil unless tar.size == 1
        tarball = CI::Tarball.new(tar[0])
        tarball.origify if tarball
      end

      def fetch_url
        return nil unless File.exist?('source/url')
        fetcher = CI::URLTarFetcher.new(File.read('source/url').strip)
        tarball = fetcher.fetch('source')
        tarball.origify if tarball
      end

      def fetch_watch
        return nil unless File.exist?('packaging/debian/watch')
        fetcher = CI::WatchTarFetcher.new('packaging/debian/watch')
        tarball = fetcher.fetch('source')
        tarball.origify if tarball
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  sourcer = CI::OrigSourceBuilder.new(release: ENV.fetch('DIST'))
  sourcer.build(DCI::OrigSourcer.tarball)
end
