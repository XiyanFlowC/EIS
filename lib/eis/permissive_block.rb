module EIS
  ##
  # An class to record where and how large a free space is.
  class PermissiveBlock
    attr_reader :location, :length

    ##
    # Create a new PermisiveBlock instance
    #
    # There is hardly to use this class manually, leave this job to
    # PermissiveMan.
    def initialize(location, length)
      @location = location
      @length = length
    end

    ##
    # Check if the given fragment overlaps with this fragment
    #
    # = Parameters
    # +location+:: +Integer+ Where the fragment begin
    # +length+:: +Integer+ How large the fragment is
    def overlap?(location, length)
      return true if @location <= location && @location + @length >= location
      return true if @location <= location + length && @location + @length >= location + length

      false
    end

    ##
    # Check if the given fragment is included in this fragment
    def include?(location, length)
      @location <= location && @location + @length >= location + length
    end

    ##
    # Merge a fragment into this.
    def merge(location, length)
      sta = @location
      ter = @location + @length # where
      fter = location + length # where the fregment ends.
      nter = ter > fter ? ter : fter
      @location = location if sta > location
      @length = nter - @location
      self
    end

    def remove(location, length)
      if include? location - 1, length + 1
        raise ArgumentError.new "[all]", "The fragment should NOT be include by this fragment"
      end

      ter = @location + @length
      cter = location + length

      if cter < ter && cter > @location
        @location = cter
        @length = ter - @location
      else
        @length = location - @location
      end
      self
    end

    ##
    # An convenient method to merge others blocks.
    def block_merge(block)
      raise ArgumentError.new "block", "type against" if block.class != EIS::PermissiveBlock

      merge block.location, block.length
    end

    ##
    # A convenient method to check if the other block is overlaped.
    def block_overlap?(block)
      return nil if block.class != PermissiveBlock

      overlap? block.location, block.length
    end

    ##
    # A convenient method to check if the other block is included
    # by this block.
    def block_include?(block)
      return nil if block.class != PermissiveBlock

      include? block.location, block.length
    end
  end
end
