# Copyright (C) 2014-2015 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'
require 'json'
require 'ostruct'
require 'net/http'
require 'net/http/exceptions'
require 'thread'

require 'oauth'
require 'oauth/signature/plaintext'

require_relative 'retry'

# BEGIN {
#
#   require 'net/http'
#
#   Net::HTTP.module_eval do
#     alias_method '__initialize__', 'initialize'
#
#     def initialize(*args,&block)
#       __initialize__(*args, &block)
#     ensure
#       @debug_output = $stderr ### if ENV['HTTP_DEBUG']
#     end
#   end
#
# }

# A simple launchpad REST API wrapper.
module Launchpad
  IO_RETRIES = 2
  @io_retry_sleeps = 8

  @mutex = Mutex.new
  @token = nil
  @conf_path = ENV['HOME']

  def self.consumer_options
    {
      signature_method: 'PLAINTEXT',
      request_token_path: '/+request-token',
      authorize_path: '/+authorize-token',
      access_token_path: '/+access-token'
    }
  end

  # @!visibility private
  def self.conf
    conf = "#{@conf_path}/tooling/confined/lp-tokens.json"
    conf = "#{@conf_path}/.config/lp-tokens.json" unless File.exist?(conf)
    conf
  end

  # @!visibility private
  def self.token_from_file(file)
    return nil unless File.exist?(file)
    JSON.parse(File.read(file), symbolize_names: true)
  end

  # @!visibility private
  # @note NOT thread safe
  def self.token
    # FIXME: @token is now unused
    # FIXME: this should be moved to a method one presumes.
    token_hash = token_from_file(conf)
    return nil unless token_hash

    site_options = { scheme: :header, site: 'https://api.launchpad.net' }
    options = consumer_options.merge(site_options)
    consumer = OAuth::Consumer.new('kubuntu-ci', '', options)
    @token = OAuth::AccessToken.from_hash(consumer, token_hash)
  end

  # @!visibility private
  # @note NOT thread safe
  def self.request_token
    # Fun story, during auth for some reason launchpad needs the flags in the
    # body while at usage it only works with flags in the header...
    site_options = { scheme: :body, site: 'https://launchpad.net' }
    options = consumer_options.merge(site_options)
    consumer = OAuth::Consumer.new('kubuntu-ci', '', options)
    request_token = consumer.get_request_token(oauth_callback: '')
    puts request_token.authorize_url(oauth_callback: '')
    loop do
      puts 'Type "done" and hit enter when done'
      break if gets.strip == 'done'
    end
    request_token.get_access_token.params
  end

  # Get or load OAuth token.
  # @note NOT thread safe
  # @return [OAuth::AccessToken]
  def self.authenticate
    token_hash = token_from_file(conf)
    unless token_hash
      token_hash = request_token
      FileUtils.mkpath(File.dirname(conf))
      File.write(conf, JSON.fast_generate(token_hash))
    end
    token
  end

  # @!visibility private
  def self.get_through_token(uri)
    if (token = Launchpad.token)
      # Token internally URIfies again without checking if it already has
      # a URI, so simply give it a string...
      Retry.retry_it(times: IO_RETRIES, sleep: @io_retry_sleeps) do
        response = token.get(uri.to_s)
        unless response.is_a? Net::HTTPSuccess
          raise Net::HTTPRetriableError.new(response.body, response)
        end
        return response.body
      end
    end
  end

  # HTTP GET. Possibly via token.
  # @note Thread safe
  # @param uri [URI] to get
  # @return [String] body of response
  def self.get(uri)
    return get_through_token(uri) if Launchpad.token

    # Set cache control.
    # Launchpad employs server-side caching, which is nice but for our purposes
    # 90% of the time we need current data, otherwise we wouldn't be polling
    # on a schedule.
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: (uri.scheme == 'https')) do |http|
      response = http.request_get(uri, 'Cache-Control' => 'max-age=0')
      unless response.is_a?(Net::HTTPSuccess)
        raise Net::HTTPRetriableError.new(response.body, response)
      end
      return response.body
    end
    nil
  end

  # HTTP POST. Only possible after {authenticate} was used to get a token!
  # @param uri [URI] to post to.
  # @return [String] body of response
  def self.post(uri)
    token = Launchpad.token
    raise 'Launchpad.authenticate must be called before any post' unless token
    # Posting always requires a token.
    Retry.retry_it(times: IO_RETRIES, sleep: @io_retry_sleeps) do
      response = token.post(uri.path, uri.query)
      unless response.is_a? Net::HTTPSuccess
        raise Net::HTTPRetriableError.new(response.body, response)
      end
      return response.body
    end
  end

  # Unlike launchpadlib we strive for minimal overhead by minimal validation.
  # Launchpadlib internally will lookup the representation spec through WADL
  # files offered by the API. We don't. We also have no advanced caching in
  # place, if one wants caching it ought to be implemented client-side.
  #  - Properties are all accessible through accessors.
  #  - Methods that do not exist will trigger a HTTP GET on the identifier
  #  - Unless the method ends with a ! in which case a HTTP POST will be done
  #  - TODO: Property changes not implemented. Would probably go through a save
  #    accessor.
  class Rubber < OpenStruct
    # @!visibility private
    def method_missing_link(name)
      data = Launchpad.get(URI(send("#{name}_link")))
      Rubber.from_json(data)
    end

    # @!visibility private
    def method_missing_collection_link(name)
      ret = []
      uri = URI(send("#{name}_collection_link"))
      loop do
        obj = Rubber.from_json(Launchpad.get(uri))
        ret += obj.entries
        return ret unless obj['next_collection_link']
        uri = URI(obj.next_collection_link)
      end
    end

    # @!visibility private
    # Build parameters.
    # For convenience reasons passing a parameter object that itself
    # responds to self_link will result in its self_link being passed.
    def build_params(name, params = {})
      params ||= {}
      params.each do |key, value|
        unless value.respond_to?(:to_h) && value.to_h.fetch(:self_link, false)
          next
        end
        params[key] = value.to_h.fetch(:self_link)
      end
      params['ws.op'] = name.to_s.chomp('!')
      params
    end

    def build_uri(params)
      uri = URI(self['self_link'])
      uri.query = URI.encode_www_form(params)
      uri
    end

    # @!visibility private
    def http_get(uri)
      ret = []
      loop do
        obj = Rubber.from_json(Launchpad.get(uri))
        return obj unless obj['entries']
        ret += obj.entries
        return ret unless obj['next_collection_link']
        uri = URI(obj.next_collection_link)
      end
      nil
    end

    def method_missing_valid?(*args)
      return true if args.empty?
      args.size == 1 && args[0].is_a?(Hash)
    end

    # @!visibility private
    def method_missing(name, *args, &_block)
      super unless method_missing_valid?(*args)

      # Pointer to different URL reflecting a different object.
      return method_missing_link(name) if self["#{name}_link"]

      # Pointer to a different URL reflecting a collection of things.
      if self["#{name}_collection_link"]
        return method_missing_collection_link(name)
      end

      uri = build_uri(build_params(name, args[0]))

      # Try to call as a 'function' on the API
      #   foo! causes a POST
      #   else we GET
      return Launchpad.post(uri) if name.to_s.end_with?('!')
      ret = http_get(uri)
      super unless ret
      ret
    end

    # Construct a {Rubber} from a JSON string.
    # @param json JSON string to construct a rubber from. Can also be a primitve
    #   that doesn't qualify for a Rubber, in which case the return type will be
    #   different.
    # @return [Rubber, Object] a Rubber instance or a primitive type, depending
    #   on what the JSON string contains
    def self.from_json(json)
      # Launchpad uses new-style JSON which can be any of the JSON literals
      # in addition to objects. To make the parser pick this up we need
      # to enable quirks mode.
      JSON.parse(json, quirks_mode: true, object_class: Rubber)
    end

    # Construct a {Rubber} from the JSON returned from an HTTP GET on an URL.
    # @param url URL to HTTP GET
    # @return [Rubber, Object] see {from_json}
    def self.from_url(url)
      uri = URI(url)
      reply = Launchpad.get(uri)
      Rubber.from_json(reply)
    end

    def self.from_path(path, prefix = 'devel')
      prefix = ''
      prefix = 'devel' unless path.start_with?('devel/') ||
                              path.start_with?('/devel/')
      Rubber.from_url("https://api.launchpad.net/#{prefix}/#{path}")
    end
  end
end
