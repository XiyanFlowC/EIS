require "elftools"
require "eis/permissive_man"
require "eis/table"

module EIS
  ##
  # The main class which holds the ELF and interacts with elftools.
  #
  # Init it first before anything you want to do with this module.
  class ElfMan
    ##
    # Create an instance of ElfMan.
    #
    # = Parameter
    # +elf_file+:: Refer to _ElfMan_'s Initializer's Parameters section.
    def initialize(elf_file)
      bind!(elf_file)
      @permission_man = PermissiveMan.new
      # @string_alloc = StringAllocator.new(@permission_man)
      # @symbol_man = SymbolMan.new self
    end

    ##
    # Initialize the elf (pass the elf file to elftools).
    #
    # *Will lost the older elf stream.*
    #
    # = Parameter
    # +elf_file+:: Target elf stream, can be _File_ or _String_ (as a path).
    def bind!(elf_file)
      # @elf_base = elf_file if elf_file.class == ELFTools::ELFFile
      if elf_file.instance_of?(File)
        @elf_base = ELFTools::ELFFile.new(elf_file)
        @base_stream = elf_file
      end
      @elf_base = ELFTools::ELFFile.new(@base_stream = File.new(elf_file, "rb")) if elf_file.instance_of?(::String)
      raise ArgumentError.new "elf_file", "elf_file must be File or String" if @elf_base.nil?
    end

    # The base of the module, ELFTools::ELFFile
    attr_reader :elf_base
    # The manager to record where is usable for Refered tables.
    attr_reader :permission_man
    # The base stream of binded elf file.
    attr_reader :base_stream
    # The stream of output elf file.
    attr_accessor :elf_out
    # attr_reader :string_alloc

    ##
    # Return first matched segment corresponding to input-value
    #
    # The result should be fine unless there are overlappings between
    # two PT_LOPD segments, which should be never happened.
    def vma_to_loc(value)
      @elf_base.segments_by_type(:PT_LOAD).each do |entry|
        if entry.vma_in? value
          return entry.vma_to_offset(value)
        end
      end
      nil
    end

    ##
    # Return the virtual memory address of inputted file offset.
    def loc_to_vma(value)
      @elf_base.segments_by_type(:PT_LOAD).each do |e|
        if e.offset_in? value then return e.offset_to_vma value end
      end
      nil
    end

    # = The Alignment Value of Specified Location
    # Get the alignment value of specified location. The **first** aimed
    # **section** will return it's vaule.
    #
    # == Parameters
    # +loc+:: The location needed to get alignment information.
    # +is_vma+:: _named_ Specified whether the location is a vma value.
    #            DEFAULT: +true+
    def align(loc, is_vma: true)
      @elf_base.sections.each do |e|
        return e.align if is_vma ? e.vma_in?(loc) : e.offset_in?(loc)
      end
      nil
    end

    ##
    # = Fetch Data from Stream by Data of ElfMan
    # Process with the given template_str and return the result
    # unpacked from the base stream.
    #
    # The template_str should be a string that contains only characters
    # l, i, h, c for signed longlong, long, short, and char,
    # as well as L, I, H, C for unsigned longlong, long, short, and char.
    #
    # And, for pointer support, if the elf is 32-bit recognize r as a
    # 32-bit pointer and R as a 64-bit pointer. Or the elf is 64-bit, r
    # will represent 64-bit pointer and R for 32-bit pointer. If the pointer
    # can be resolve, the value will be the offset of the file, or be nil.
    # In addition, if the pointer is nullable, [Unimplemented].
    #
    # This subroutine will translate them to corresponding unpack string
    # with endian information from ELFTools::ELFFile. And seek, read and
    # unpack data from the basic stream.
    #
    # So this subroutine will change the stream position.
    #
    # == Parameters
    # +location+:: The location, which will refer to vma or offset is depends on the mode.
    # +template_str+:: The unpack template string.
    # +mode+:: _named_ The mode. Can be ':offset' or ':vma'.
    # +shiftable+:: _named_ Whether the data can be shifted. If so, the area will be marked in the permission_man.
    #
    # == Examples
    # <tt>elf.fetch_data(0x25ff20, "hhhhiil", mode: :vma)</tt>
    # <tt>elf.fetch_data(0x255ffc, "hhhh", mode: :offset)</tt>
    # <tt>elf.fetch_data(0x1000, "llll")</tt>
    def fetch_data(location, template_str, mode: :vma, shiftable: false)
      ori_loc = @base_stream.loc
      @base_stream.seek(location) if mode == :offset
      @base_stream.seek(vma_to_loc(location)) if mode == :vma

      unpackstr = ""
      length = 0
      refs = []
      idx = 0
      template_str.each_char do |c|
        # unsigned
        if c == "I"
          length += 4
          unpackstr << "L>" if @elf_base.endian == :big
          unpackstr << "L<" if @elf_base.endian == :little
        end
        if c == "H"
          length += 2
          unpackstr << "S>" if @elf_base.endian == :big
          unpackstr << "S<" if @elf_base.endian == :little
        end
        if c == "C"
          length += 1
          unpackstr << "C"
        end
        if c == "L"
          length += 8
          unpackstr << "Q>" if @elf_base.endian == :big
          unpackstr << "Q<" if @elf_base.endian == :little
        end
        # signed
        if c == "i"
          length += 4
          unpackstr << "l>" if @elf_base.endian == :big
          unpackstr << "l<" if @elf_base.endian == :little
        end
        if c == "h"
          length += 2
          unpackstr << "s>" if @elf_base.endian == :big
          unpackstr << "s<" if @elf_base.endian == :little
        end
        if c == "c"
          length += 1
          unpackstr << "c"
        end
        if c == "l"
          length += 8
          unpackstr << "q>" if @elf_base.endian == :big
          unpackstr << "q<" if @elf_base.endian == :little
        end
        # refer auto conv
        if c == "r" || c == "R"
          t = -1
          if @elf_base.instance_of?(32)
            t = 0 if c == "r"
            t = 1 if c == "R"
          elsif @elf_base.instance_of?(64)
            t = 1 if c == "R"
            t = 0 if c == "r"
          end
          if t == 1
            length += 8
            unpackstr << "Q>" if @elf_base.endian == :big
            unpackstr << "Q<" if @elf_base.endian == :little
          else
            length += 4
            unpackstr << "L>" if @elf_base.endian == :big
            unpackstr << "L<" if @elf_base.endian == :little
          end
          refs << idx
        end
        idx += 1
      end

      @permission_man.register(location, length)
      ans = @base_stream.sysread(length).unpack(unpackstr)

      refs.each do |refi|
        ans[refi] = vma_to_loc ans[refi]
      end

      @base_stream.loc = ori_loc # 恢复本来位置，保证其他系统正常。
      ans
    end
  end
end
