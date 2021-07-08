require "elftools"
require "eis/table"

module EIS
  ##
  # The main class which holds the ELF and interacts with elftools.
  #
  # Init it first before anything you want to do with this module.
  #
  # = Initializer's Parameters
  # The param +elf_file+ can be _File_, _ELFTools::ELFFile_, or _String_.
  # [<tt>File</tt>] In this case, the programme will recognize it and try
  #                 to pass this stream to elftools
  #
  # [<tt>ELFTools::ELFFile</tt>] *discard* In this case, the programme will store the
  #                              Object directly
  #
  # [<tt>String</tt>] In this case, the programme will open the given *path*
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
    def initialize(elf_file)
      read(elf_file)
      @permission_man = PermissiveMan.new
      @string_alloc = StringAllocator.new(@permission_man)
      @symbol_man = SymbolMan.new self
    end

    ##
    # Initialize the elf (pass the elf file to elftools).
    #
    # *Will lost the older elf stream.*
    #
    # = Parameter
    # +elf_file+:: Target elf stream, can be _File_ or _String_ (as a path).
    def read(elf_file)
      # @elf_base = elf_file if elf_file.class == ELFTools::ELFFile
      if elf_file.instance_of?(File)
        @elf_base = ELFTools::ELFFile.new(elf_file)
        @base_stream = elf_file
      end
      @elf_base = ELFTools::ELFFile.new(@base_stream = File.new(elf_file, "rb")) if elf_file.instance_of?(::String)
      raise ArgumentError.new "elf_file", "elf_file must be File or String" if @elf_base.nil?
    end

    attr_reader :elf_base
    attr_reader :permission_man
    attr_reader :string_alloc
    attr_reader :symbol_man
    attr_reader :base_stream
    attr_accessor :elf_out

    ##
    # Get a new table related to this class
    def new_table(location, count, type)
      rst = Table.new(location, count, type, self)
      @symbol_man.reg_symb(location, rst)
      rst
    end

    def vma_to_loc(value)
      @elf_base.segment_by_type(:PT_LOAD).vma_to_offset value
    end

    def loc_to_vma(value)
      @elf_base.segment_by_type(:PT_LOAD).offset_to_vma value
    end
  end
end
