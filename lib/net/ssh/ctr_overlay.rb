# frozen_string_literal: true
#
# Copyright (C) 2018 Miklos Fazekas <mfazekas@szemafor.com>
# Copyright (C) 2008 Jamis Buck
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'delegate'
require 'net/ssh'

# Efficient CTR overlay for net-ssh
# - Uses a cipher thread to fill a key queue to xor against
# - Dynamically grows the key queue as it encounters under runs
# - Uses native xor implementation to reduce it's bottlenecking.
# This is fully compatible with the orignal CTR behavior and in fact passes
# net-ssh's test suite, it simply changes the internal to more performant
# options.

# Monkey patch transport with cipher overlay from
# https://github.com/net-ssh/net-ssh/pull/570
module Net::SSH::Transport
  class OpenSSLAESCTR < SimpleDelegator
    def initialize(original)
      super
      @was_reset = false
    end

    def block_size
      16
    end

    def self.block_size
      16
    end

    def reset
      @was_reset = true
    end

    def iv=(iv_s)
      super unless @was_reset
    end
  end
end

module Net::SSH::Transport
  VERSION__ = Net::SSH::Version::CURRENT.to_s
  class CipherFactory
    unless Gem::Dependency.new('', '~> 4.2.0').match?('', VERSION__)
      raise <<-ERROR
Net::SSH version too new, check if https://github.com/net-ssh/net-ssh/pull/569
was applied in this version, if not make sure our overlay is up-to-date and
bump the version dependency check above the origin of this exception.
ERROR
    end

    remove_const(:SSH_TO_OSSL)

    SSH_TO_OSSL = {
      "3des-cbc"                    => "des-ede3-cbc",
      "blowfish-cbc"                => "bf-cbc",
      "aes256-cbc"                  => "aes-256-cbc",
      "aes192-cbc"                  => "aes-192-cbc",
      "aes128-cbc"                  => "aes-128-cbc",
      "idea-cbc"                    => "idea-cbc",
      "cast128-cbc"                 => "cast-cbc",
      "rijndael-cbc@lysator.liu.se" => "aes-256-cbc",
      "arcfour128"                  => "rc4",
      "arcfour256"                  => "rc4",
      "arcfour512"                  => "rc4",
      "arcfour"                     => "rc4",

      "3des-ctr"                    => "des-ede3",
      "blowfish-ctr"                => "bf-ecb",

      "aes256-ctr"                  => "aes-256-ctr",
      "aes192-ctr"                  => "aes-192-ctr",
      "aes128-ctr"                  => "aes-128-ctr",
      "cast128-ctr"                 => "cast5-ecb",

      "none"                        => "none",
    }

    def self.get(name, options={})
      ossl_name = SSH_TO_OSSL[name] or raise NotImplementedError, "unimplemented cipher `#{name}'"
      return IdentityCipher if ossl_name == "none"
      cipher = OpenSSL::Cipher.new(ossl_name)

      cipher.send(options[:encrypt] ? :encrypt : :decrypt)

      cipher.padding = 0

      if name =~ /-ctr(@openssh.org)?$/
        if ossl_name !~ /-ctr/
          cipher.extend(Net::SSH::Transport::CTR)
        else
          cipher = Net::SSH::Transport::OpenSSLAESCTR.new(cipher)
        end
      end
      cipher.iv = Net::SSH::Transport::KeyExpander.expand_key(cipher.iv_len, options[:iv], options) if ossl_name != "rc4"

      key_len = KEY_LEN_OVERRIDE[name] || cipher.key_len
      cipher.key_len = key_len
      cipher.key = Net::SSH::Transport::KeyExpander.expand_key(key_len, options[:key], options)
      cipher.update(" " * 1536) if (ossl_name == "rc4" && name != "arcfour")

      return cipher
    end

    # Returns a two-element array containing the [ key-length,
    # block-size ] for the named cipher algorithm. If the cipher
    # algorithm is unknown, or is "none", 0 is returned for both elements
    # of the tuple.
    # if :iv_len option is supplied the third return value will be ivlen
    def self.get_lengths(name, options = {})
      ossl_name = SSH_TO_OSSL[name]
      if ossl_name.nil? || ossl_name == "none"
        result = [0, 0]
        result << 0 if options[:iv_len]
      else
        cipher = OpenSSL::Cipher.new(ossl_name)
        key_len = KEY_LEN_OVERRIDE[name] || cipher.key_len
        cipher.key_len = key_len

        block_size =
          case ossl_name
          when "rc4"
            8
          when /\-ctr/
            Net::SSH::Transport::OpenSSLAESCTR.block_size
          else
            cipher.block_size
          end

        result = [key_len, block_size]
        result << cipher.iv_len if options[:iv_len]
      end
      result
    end
  end
end
