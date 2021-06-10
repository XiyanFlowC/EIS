require 'elftools'

module EIS
  $eis_shift = 1 # the shift aggressivity 0 none, 1 str, 2 ptr

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
  # The main class which holds the ELF and interacts with elftools. 
  #
  # Init it first before anything you want to do with this module. 
  #
  # = Initializer's Parameters
  # The param +elf_file+ can be _File_, _ELFTools::ELFFile_, or _String_.
  # [<tt>File</tt>] In this case, the programe will regonize it and try
  #                 to pass this stream to elftools
  #
  # [<tt>ELFTools::ELFFile</tt>] *discard* In this case, the programe will store the
  #                              Object directly
  #
  # [<tt>String</tt>] In this case, the programe will open the given *path* 
  #                   with the mode 'rb' and passes the stream to elftools.
  #
  # = Example
  # <tt>foo = EIS::ElfMan.new(File.new('bar.elf', 'rb'))</tt>
  #
  # and this form is also fine:
  #
  # <tt>foo = EIS::ElfMan.new('bar.elf', 'rb')</tt>
  # 
  # Then you can use it like:
  # 
  # <tt>foo.extract(bar)</tt>
  class ElfMan
    ##
    # Create an instance of ElfMan.
    #
    # = Parameter
    # +elf_file+:: Refer to _ElfMan_'s Initializer's Parameters section.
    def initialize elf_file
      init!(elf_file)
      @permission_man = PermissiveMan.new
      @string_alloc = StringAllocater.new(@permission_man)
    end

    ##
    # Initialize the elf (pass the elf file to elftools).
    #
    # *Will lost the older elf stream.*
    #
    # = Parameter
    # +elf_file+:: Target elf stream, can be _File_ or _String_ (as a path).
    def init! elf_file
      # @elf_base = elf_file if elf_file.class == ELFTools::ELFFile
      @elf_base, @base_stream = ELFTools::ELFFile.new(elf_file), elf_file if elf_file.class == File
      @elf_base = ELFTools::ELFFile.new(@base_stream = File.new(elf_file, 'rb')) if elf_file.class == ::String
      raise ArgumentError.new 'elf_file', 'elf_file must be File or String' if @elf_base == nil
    end

    attr_reader :elf_base
    attr_reader :permission_man
    attr_reader :string_alloc

    ##
    # Get the base stream (shoud be readonly)
    def base_stream
      @base_stream
    end

    ##
    # Get the output stream
    def elf_out
      @elf_out
    end

    ##
    # Set the output stream
    def elf_out=(val)
      @elf_out = val
    end

    ##
    # Get a new table relatied to this class
    def new_table(location, count, type)
      return Table.new(location, count, type, self)
    end

    def vma_to_loc(value)
      @elf_base.segment_by_type(:PT_LOAD).vma_to_offset value
    end

    def loc_to_vma(value)
      @elf_base.segment_by_type(:PT_LOAD).offset_to_vma value
    end
  end

  ##
  # Table is a class to record where and how large a structure array is.
  #
  # = Purpose
  # * Record the position (and the size) of a structure
  # * Provides convinient methods to extract this structure array
  # * Provides enough free space so that user can change it's behavior
  #
  # = Example
  # <tt>tbl = Table.new 0x2ff59d3, 32, Dialog
  # tbl.elf = elf # these two lines are equal to elf.new_table 0x2ff59d3, 32, Dialog
  # tbl.extract do |entry|
  #   puts entry.id, entry.text
  # end
  # 
  # tbl.each do |entry|
  #   entry.id = 5 if entry.text == 'Set up.'
  # end
  # 
  # outelf = File.new('./output.elf', 'wb')
  # elf.output = outelf
  # tbl.write #this action will sync the modifications to elf output stream</tt>
  class Table
    ##
    # Create a new table instance
    # 
    # = Parameters
    # +location+::  +Number+ A number to record where the table located.
    # +count+::     +Number+ How many entries this table contains.
    # +type+::      +EIS::BinStruct+ The type of entry.
    def initialize(location, count, type, elf_man)
      @location = location
      @count = count
      @type = type
      @elf = elf_man
    end

    attr_reader :location, :count

    ##
    # Read table contant from specified ElfMan
    #
    # = Code Block
    # A block with one parameter which recieve the read 
    # ENTRY datum instance.
    def read()
      loc = @elf.vma_to_loc @location
      @data = []

      @elf.base_stream.seek loc
      i = 0
      @count.times do
        begin
          inst = @type.new
          inst.read(@elf.base_stream)
        rescue Errno::EINVAL
          raise "Table#read(): fatal: seek failed. @#{i}"
          return
        end
        puts("Table#read(): read #{inst}") if $eis_debug
        @data << inst
        i += 1
        yield(inst) if block_given?
      end
    end
    
    def data
      @data
    end

    def data= value
      raise ArgumentError.new 'value', "Size error. (#{value.size} against #{@count})" if value.size != @count
      @data = value
    end

    def set_data! value
      @data = value
    end

    ##
    # Write table contants to specified ElfMan
    def write()
      raise ArgumentError.new('elfman', "#{elfman.class} against to EIS::ElfMan") if elfman.class != ElfMan

      loc = elfman.vma_to_loc @location
      @elf.elf_out.seek loc

      @data.each do |datum|
        datum.write(@elf.elf_out)
      end
    end
  end

  ##
  # An class to record where and how large a free space is. 
  class PermissiveBlock
    attr_reader :location, :length

    ##
    # Create a new PermisiveBlock instance
    #
    # There is hardly to use this class manually, leave this job to
    # PermissiveMan.
    def initialize location, length
      @location = location
      @length = length
    end

    ##
    # Check if the given fragment overlaps with this fragment
    #
    # = Parameters
    # +location+:: +Integer+ Where the fragment begin
    # +length+:: +Integer+ How large the fragment is
    def overlap? location, length
      return true if @location <= location && @location + @length >= location
      return true if @location <= location + length && @location + @length >= location + length
      false
    end

    ##
    # Check if the given fragment is included in theis fragment
    def include? location, length
      @location <= location && @location + @length >= location + length
    end

    ##
    # Merge a fragment into this. 
    def merge location, length
      sta = @location
      ter = @location + @length # where
      fter = location + length # where the fregment ends. 
      nter = ter > fter ? ter : fter
      @location = location if sta > location
      @length = nter - @location
      self
    end

    def remove(location, length)
      raise ArgumentError.new '[all]', 'The fragment should NOT be include by this fragment' if include? location-1, length+1
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
    # An convinient method to merge others blocks. 
    def block_merge block
      raise ArgumentError.new 'block', 'type against' if block.class != EIS::PermissiveBlock
      merge block.location, block.length
    end

    ##
    # A convinient method to check if the other block is overlaped. 
    def block_overlap? block
      return nil if block.class != PermissiveBlock
      overlap? block.location, block.length
    end

    ##
    # A convinient method to check if the other block is included 
    # by this block.
    def block_include? block
      return nil if block.class != PermissiveBlock
      include? block.location, block.length
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

    attr_accessor :data, :ref, :count

    ##
    # Read from stream
    def read(stream)
      @data = []
      @ref = stream.sysread(4).unpack("L<")[0] if @elf_man.elf_base.endian == :little
      @ref = stream.sysread(4).unpack("L>")[0] if @elf_man.elf_base.endian == :big
      puts("Ref#read(): @ref = #{@ref}") if $eis_debug
    end

    def readref(stream)
      ploc = stream.pos
      # 为读取到的指针解引用。
      loc = @elf_man.vma_to_loc @ref # 解引用 
        
      # 寻址到对应位置，准备载入。
      # --------------------------------
      stream.seek loc

      i = 0
      @limit.call.times do
        tmp = @type.new
        # begin
          tmp.read(stream) # 载入
        # rescue Errno::EINVAL
        #   puts "Ref#readref(): fatal: seek failed. @#{i}"
        #   stream.seek ploc
        #   break
        # end
        puts("Ref#readref(): read[#{i}] #{tmp}") if $eis_debug
        i += 1
        @data << tmp # 加入数据数组
      end
      @elf_man.permission_man.register(loc, @data.size * @data[0].size) if $eis_shift >= 2

      stream.seek ploc
    end

    def write(stream)
      loc = @elf_man.vma_to_loc @ref # 获取原始位置
      loc = @elf_man.permission_man.alloc(@data.size * @data[0].size) if $eis_shift >= 2 # 激进的指针重整策略需要重新分配指针表空间
      raise "Virtual memory run out" if loc.nil?
      rloc = [loc].pack("L<")[0] if @elf_man.elf_base.endian == :little
      rloc = [loc].pack("L>")[0] if @elf_man.elf_base.endian == :big
      stream.syswrite(rloc)
      nloc = stream.pos # 保存当前流位置，避免后续读取／写入混乱
      
      stream.seek loc
      @data.each do |entry|
        entry.write(stream)
      end

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
        readdelay = [] # 稍后再读取的引用，确保无论数量限制先后，都能正确读取
        @fields.each do |key, entry|
          readdelay << entry if entry.class == Ref

          entry.read(stream)
        end

        readdelay.each do |entry|
          entry.readref(stream) # 此时再解引用，这时数量限制数据必然已经读入
        end
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
