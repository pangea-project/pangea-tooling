# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'net/ssh'
require 'xorcist'

# Efficient CTR overlay for net-ssh
# - Uses a cipher thread to fill a key queue to xor against
# - Dynamically grows the key queue as it encounters under runs
# - Uses native xor implementation to reduce it's bottlenecking.
# This is fully compatible with the orignal CTR behavior and in fact passes
# net-ssh's test suite, it simply changes the internal to more performant
# options.
module Net::SSH::Transport::CTR::CTROverlay
  # We'll prepend class methods.
  module ClassMethods
    # Helper class to establish a key queue. It is differnet from a regular
    # SizedQueue in that it automatically grows itself if it encounters an
    # under run.
    class KeyQueue < SizedQueue
      # At a standard block size of 16 we'll hold up to 4 MiB for the key stream,
      # that's about 2.6 million keys at the most.
      # The actual key_queue size is grown dynamically as we encounter buffer
      # underruns.
      KEY_QUEUE_MAX = (4 * 1024 * 1024) / 16

      def cap?
        # Default to false, the first pop we'll want to wait on ALL the time!
        # Once we had at least once underrun @cap will be the actual capyness.
        @cap ||= false
      end

      def update_cap
        @cap = max < KEY_QUEUE_MAX
      end

      def pop
        begin
          return super(cap?) # wait if we have a max size queue
        rescue ThreadError
          # When we have a buffer underrun we bump the queue size up to cap.
          warn "Buffer underrun, increasing queue length #{max * 2}"
          self.max *= 2
          update_cap
          retry
        end
        nil
      end
    end

    # Prepends on the net-ssh extender method. net-ssh creates an ossl cipher
    # and then runs the CTR extend on that object.
    def extended(orig)
      super # let original extender run, then we'll override what it did.

      orig.instance_eval {
        @key_queue = KeyQueue.new(2048)

        def new_cipher_thraed
          # https://www.internet2.edu/presentations/jt2008jan/20080122-rapier-bennett.htm
          Thread.new do
            loop do
              @key_queue << _update(@counter)
              increment_counter!
            end
          end
        end
        singleton_class.send(:private, :new_cipher_thraed)

        def update(data)
          @cipher_thread ||= new_cipher_thraed
          @remaining += data

          encrypted = ''
          offset = 0
          while (@remaining.bytesize - offset) >= block_size
            encrypted += Xorcist.xor(@remaining.slice(offset, block_size),
                                     @key_queue.pop)
            offset += block_size
          end
          # only modify remaining after loop, we do not need it modified while
          # looping
          @remaining = @remaining.slice(offset..-1)

          encrypted
        end

        def final
          s = @remaining.empty? ? '' : Xorcist.xor(@remaining, @key_queue.pop)
          @remaining = ''
          s
        end
      }
    end
  end

  def self.prepended(base)
    class << base
      prepend ClassMethods
    end
  end
end

# Monkey patch with overlay.
module Net::SSH::Transport::CTR
  prepend CTROverlay
end
