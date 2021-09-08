module EIS
  ##
  # = StringAllocator
  # A allocator accesses the permissive block manager directly to
  # provides a more friendly string allocation methods.
  # == Initialize
  # Only one parameter, the permissive man.
  class StringAllocator
    def initialize(permissive_man)
      @perm_man = permissive_man
      @alloc_tbl = Hash.new nil
    end

    ##
    # Allocate an string. The string should have not a '\0'
    # as the ending. If the string is registered already,
    # the same location will be returned.
    def salloc(string, align: 8)
      loc = @alloc_tbl[string]
      return loc unless loc.nil?

      leng = string.bytesize
      leng = leng + align & ~(align - 1)
      @alloc_tbl[string] = @perm_man.alloc(leng, align: align)
    end

    ##
    # Register a string, the string should have not a '\0'
    # as the ending.
    def register(loc, string, align: 8)
      leng = string.bytesize
      leng = leng + align & ~(align - 1)
      @perm_man.register(loc, leng)
    end
  end
end
