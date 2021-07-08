require 'elftools'
require_relative 'ELFMan'
require_relative 'Table'
require_relative 'PermissiveBlock'

module EIS
  $eis_shift = 1 # the shift aggressivity 0 none, 1 str, 2 ptr
  # 请不要设为2，激进的指针重整策略现在暂不可用

  ##
  # EIS Error type, raised by EIS module. It's just an Empty child
  # of StandardError
  EISError = Class.new StandardError

  ##
  # ArgumentError, raised when an unexcepted value be passed to
  # routine.
  #
  # = Attributes
  # * _reason_: *readonly* the reason why this error be raised
  # * _argument_name_: *readonly* the argument name which has error
  # be detacted.
  class ArgumentError < EISError
    attr_reader :reason, :argument_name
    
    def initialize argument_name, reason
      @argument_name = argument_name
      @reason = reason
    end

    ##
    # An default description to this error
    def to_s
      "Argument #{argument_name} is incorrect, because: #{reason}"
    end
  end

  ##
  # = SymbolMan
  # The symbols manager
  # = Perpose
  # For manage the table's address and coresponding naming
  class SymbolMan
    def initialize elf_man
      @symb = Hash.new(nil)
      @elf_man = elf_man
    end

    def reg_symb(location, tbl)
      @symb[location] = tbl
    end

    def get_addr(tbl)
      @elf_man.loc_to_vma @symb.index(tbl)
    end

    def get_loc(tbl)
      @symb.index(tbl)
    end

    def get_inst(addr)
      @symb[addr]
    end
  end

  ##
  # PermissiveBlock Manager 
  #
  # Use this to register, check, delete permissive block. 
  #
  # If an ElfHub has created one automatically already, you don't need to 
  # create me unless you need manully control the behavior(s) of the 
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
      @registerTable = Array.new
    end

    attr_reader :registerTable

    ##
    # Allocate a free space
    def alloc(length, align: 8)
      length = length + align - 1 & ~(align - 1)
      @registerTable.each do |e|
        if e.include? e.location, length
          loc = e.location
          e.remove e.location, length

          @registerTable.delete(e) if e.length == 0
          return loc
        end
      end

      nil
    end

    ##
    # Register a fragment
    def register(location, length, align: 8)
      length = length + align - 1 & ~(align - 1)
      @registerTable.each do |entry|
        if entry.overlap? location, length
          entry.merge location, length
          return @registerTable
        end
      end
      @registerTable << PermissiveBlock.new(location, length)
    end

    ##
    # Compare each entry in the manager, merge and reduce them to 
    # prevent fragment.
    #
    # = Remark
    # It's better to execute this methods before read from this class
    # or may cause a bad preference. 
    def global_merge
      @registerTable.each do |entry|
        @registerTable.each do |ie|
          next if ie == entry
          if ie.block_include? entry
            @registerTable.delete entry
          elsif ie.block_overlap? entry
            ie.block_merge entry
            @registerTable.delete entry
          end
        end
      end
    end

    ##
    # Remove an block from set
    def remove(location, length)
      @registerTable.each do |entry|
        if entry.include? location, length
          register entry.location, location - entry.location
          register location + length, entry.location + entry.length - location - length
          @registerTable.delete entry
        end

        entry.remove location, length if entry.overlap? location, length
        @registerTable.delete(entry) if entry.length == 0
      end
    end
  end

  ##
  # = StringAllocater
  # A allocater accesses the permissive block manager directly to
  # provides a more friendly string allocation methods.
  # == Initialize
  # Only one parameter, the permissiveman.
  class StringAllocater
    def initialize(permissiveman)
      @perm_man = permissiveman
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
      @alloc_tbl[string] = @perm_man.alloc(leng)
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

  StructRegisterTable = Hash.new(nil)

  ##
  # A _Struct_ to store the meta data of fields in _BinStruct_
  #
  # = Fields
  # _:id_::     The appear sort of this field
  # _:type_::   The type of this field
  Field = Struct.new(:type, :count, :control)

  ##
  # Pointer deref, co-operate with BinStruct
  class Ref
    ##
    # Create a new Ref type. 
    #
    # = Parameters
    # * count: The pointers array's 
    # * controls: See the following section
    #
    # = Controls
    # * <tt>controls[1]</tt> The type that this ref point to
    # * <tt>controls[2]</tt> The _ElfMan_ (for vma-loc calc)
    def initialize(count, controls)
      @type = controls[1]
      @count = count
      @limit = count.class == Symbol ? controls[0].method(count) : ->{count}
      @elf_man = controls[2]
    end

    def size
      4
    end

    attr_accessor :data, :count# , :ref

    ##
    # Read from stream
    def read(stream)
      # @data = []
      @data = stream.sysread(4).unpack("L<")[0] if @elf_man.elf_base.endian == :little
      @data = stream.sysread(4).unpack("L>")[0] if @elf_man.elf_base.endian == :big
      @elf_man.new_table(@elf_man.vma_to_loc(@data), @limit.call, @type)
      puts("Ref#read(): @ref = #{@ref}") if $eis_debug
    end

    # def readref(stream)
    #   ploc = stream.pos
    #   # 为读取到的指针解引用。
    #   loc = @elf_man.vma_to_loc @ref # 解引用 
        
    #   # 寻址到对应位置，准备载入。
    #   # --------------------------------
    #   stream.seek loc

    #   i = 0
    #   @limit.call.times do
    #     tmp = @type.new
    #     # begin
    #       tmp.read(stream) # 载入
    #     # rescue Errno::EINVAL
    #     #   puts "Ref#readref(): fatal: seek failed. @#{i}"
    #     #   stream.seek ploc
    #     #   break
    #     # end
    #     puts("Ref#readref(): read[#{i}] #{tmp}") if $eis_debug
    #     i += 1
    #     @data << tmp # 加入数据数组
    #   end
    #   @elf_man.permission_man.register(loc, @data.size * @data[0].size) if $eis_shift >= 2

    #   stream.seek ploc
    # end

    def write(stream)
      loc = @elf_man.vma_to_loc @data # 获取原始位置
      # loc = @elf_man.permission_man.alloc(@data.size * @data[0].size) if $eis_shift >= 2 # 激进的指针重整策略需要重新分配指针表空间
      # raise "Virtual memory run out" if loc.nil?
      rloc = [loc].pack("L<")[0] if @elf_man.elf_base.endian == :little
      rloc = [loc].pack("L>")[0] if @elf_man.elf_base.endian == :big
      stream.syswrite(rloc)
      nloc = stream.pos # 保存当前流位置，避免后续读取／写入混乱
      
      # stream.seek loc
      # @data.each do |entry|
      #   entry.write(stream)
      # end

      stream.seek nloc # 恢复流位置
    end
  end

  ##
  # The basic unit to dear with the exportation and importation
  #
  # = Example
  # <tt>
  # class A < EIS::BinStruct
  #   int8 :test, 4
  #   int16 :limit
  #   ref A, length = 999
  # end
  #</tt>
  # = Remarks
  # The methods used in the declair should be mixin or by other
  # methods to add.
  # 
  # If required the utils.rb, int8-64, uint8-64 will be available. 
  # The registered method should handle:
  # * name
  # * length
  # and register the id, type and controls (as nil if unused) as a
  # Field into class holds 
  class BinStruct
    @@types = Hash.new nil

    ##
    # Initializae of this basic
    def self.init(elf)
      @@elf = elf
    end

    def self.ref(type, name, count)
      return register_field(name, count, Ref, [@@types[type.to_s], @@elf])
    end

    def self.inherited(child)
      @@types[child.to_s] = child # register claimed types, so that the other children can find each other
      child.class_variable_set '@@fieldsRegisterTable', Hash.new(nil) # this val shouldn't impact the parent
      # child.class_variable_set '@@elf', @@elf
      child.class_eval <<-EOD
      def initialize
        @fields = Hash.new
        @@fieldsRegisterTable.each do |name, cnt|
          @fields[name] = cnt.type.new(cnt.count, [self] + cnt.control)
        end
      end

      def size
        ret = 0
        @fields.each do |k,e|
          ret += e.size
        end

        ret
      end

      def self.elf
        @@elf
      end

      def fields
        @fields.dup
      end

      def self.fieldsRegisterTable
        @@fieldsRegisterTable
      end

      def read(stream)
        # readdelay = [] # 稍后再读取的引用，确保无论数量限制先后，都能正确读取
        @fields.each do |key, entry|
          # readdelay << entry if entry.class == Ref

          entry.read(stream)
        end

        # readdelay.each do |entry|
        #   entry.readref(stream) # 此时再解引用，这时数量限制数据必然已经读入
        # end # 现在暂时不需要。
      end

      def write(stream)
        @fields.each do |key, entry|
          entry.write(stream)
        end
      end
      EOD
    end
  end
end
