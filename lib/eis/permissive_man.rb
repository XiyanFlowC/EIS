require "eis/permissive_block"

module EIS
  ##
  # PermissiveBlock Manager
  #
  # Use this to register, check, delete permissive block.
  #
  # If an ElfHub has created one automatically already, you don't need to
  # create me unless you need manually control the behavior(s) of the
  # ElfHub.
  #
  # = Example
  # <tt>pm = PermissiveMan.new
  # pm.register 0x8600, 128
  # pm.include? 0x860f, 16 # => true
  # pm.remove 0x8618, 1024 #it's fine to remove a never exist fregment
  # pm.include? 0x860f, 16 # => false</tt>
  # # after many reg/rm ...
  # pm.global_merge # Very important! Or causes wrone result!
  # pm.alloc(0, 16)
  # #other alloc ...
  #
  # = Remarks
  # After register a lots of fregment, the fragments will here and ther
  # even they are overlapped or included. So, to solve this, it's
  # recommended to run global_merge command before you use it to detect
  # or after a lots of register.
  class PermissiveMan
    def initialize
      @register_table = []
    end

    attr_reader :register_table

    ##
    # Allocate a free space
    def alloc(length, align: 8)
      length = length + align - 1 & ~(align - 1)
      @register_table.each do |e|
        next unless e.include? e.location, length

        loc = e.location
        e.remove e.location, length

        @register_table.delete(e) if e.length == 0

        puts "assigned #{loc.to_s(16)} for #{length} byte(s)." if EIS::Core.eis_debug
        return loc
      end

      nil
    end

    ##
    # Register a fragment
    def register(location, length, align: 8)
      length = length + align - 1 & ~(align - 1)
      puts "PermMan: Registered #{location.to_s(16)}: #{length}" if EIS::Core.eis_debug
      @register_table.each do |entry|
        if entry.overlap? location, length
          entry.merge location, length
          return @register_table
        end
      end
      @register_table << PermissiveBlock.new(location, length)
    end

    ##
    # Compare each entry in the manager, merge and reduce them to
    # prevent fragment.
    #
    # = Remark
    # It's better to execute this methods before read from this class
    # or may cause a bad preference.
    def global_merge
      @register_table.each do |entry|
        @register_table.each do |ie|
          next if ie == entry

          if ie.block_include? entry
            @register_table.delete entry
          elsif ie.block_overlap? entry
            ie.block_merge entry
            @register_table.delete entry
          end
        end
      end
    end

    ##
    # Remove an block from set
    def remove(location, length)
      @register_table.each do |entry|
        if entry.include? location, length
          register entry.location, location - entry.location
          register location + length, entry.location + entry.length - location - length
          @register_table.delete entry
        end

        entry.remove location, length if entry.overlap? location, length
        @register_table.delete(entry) if entry.length == 0
      end
    end
  end
end
