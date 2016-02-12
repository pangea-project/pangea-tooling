require 'thread'

# Thread-safe queue container.
# Queue is monkey patched to support incredibly useful Array<=>Queue conversion.
class Queue
  alias_method :super_init, :initialize

  def initialize(array = nil)
    super_init
    return if array.nil?
    unless array.is_a?(Array)
      raise 'Queue can only be constructed from an Array'
    end
    array.each { |i| self << i }
  end

  def to_a
    # Queue isn't exactly the most nejoable thing in the world as it doesn't
    # allow for random access so you cannot iterate over it, and it doesn't
    # implement dup nor clone so you can't deep copy it either.
    # Now since we need to iterate queue to convert it in an array and iteration
    # means destructive popping we first need to pop it into an Array and then
    # iterate over the array to push the values back into the queue. Quite mad.
    ret = []
    ret << pop until empty?
    ret.each { |i| self << i }
    ret
  end
end
