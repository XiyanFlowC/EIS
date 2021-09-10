require "active_support/all"

require "eis/bin_struct"
require "eis/table"
require "eis/table_man"
require "eis/elf_man"
require "eis/error"
require "eis/permissive_block"
require "eis/permissive_man"
require "eis/ref"
require "eis/string_allocator"
require "eis/symbol_man"
require "eis/types"

require "eis/filesrv/xmlio"

module EIS
  ##
  # A _Struct_ to store the meta data of fields in _BinStruct_
  #
  # = Fields
  # _:id_::     The appear sort of this field
  # _:type_::   The type of this field
  Field = Struct.new(:type, :count, :control)

  ##
  # = Exporting and Importing Core Class
  # Provides a way to save and load to/from files so that
  # external tools can make changes to the contents so that
  # the EISCore can load modified contents and imports the
  # modification to the elf.
  #
  # == Examples
  # <tt>
  # core = EIS::Core.new "myelf.elf", "out.xml"
  # core.table('table', 0x2322fc, 2, FileAllocationTable)
  # core.read
  # core.save
  # core.select('table') do |x| # each entry
  #   x.Length = 0 if x.Length >= 3000
  # end
  # # or:
  # tbl = core.select('table') # a list
  # tbl.each {|x| x.Length = 0 if x.Length >= 3000}
  # </tt>
  class Core
    @eis_shift = 1 # the shift aggressively 0 none, 1 str, 2 ptr
    # 请不要设为2，激进的指针重整策略现在暂不可用
    @eis_debug = nil
    class << self
      attr_accessor :eis_shift, :eis_debug, :elf
    end

    def initialize(elf_path, target_elf = "output.elf", fpath: nil, fiomgr: EIS::XMLIO)
      # File.new(target_elf, "w").close unless File.exist? target_elf
      @elf = EIS::Core.elf = EIS::ElfMan.new elf_path
      @elf.elf_out = @out_elf = File.new(target_elf, "r+b")
      warn "File length wierd!" if @out_elf.size != @elf.base_stream.size
      # @path = path
      # @tbls = Hash.new nil
      @permission_man = PermissiveMan.new
      @table_manager = TableMan.new @elf, @permission_man
      @string_allocator = StringAllocator.new @permission_man
      @fiomgr = fiomgr.new @elf, @table_manager, @permission_man, fpath unless fpath.nil?

      EIS::BinStruct.elf = @elf
      EIS::BinStruct.string_allocator = @string_allocator
      EIS::BinStruct.table_manager = @table_manager
    end

    ##
    # Declare a new table
    #
    # = Parameters
    # +name+:: table's name.
    # +location+:: table's start memory address.
    # +length+:: the count of entries in the table.
    # +type+:: the entries' type.
    def table(name, location, length, type)
      tbl = Table.new(location, length, type, @elf)
      @table_manager.register_table(tbl, name)
      tbl
    end

    ##
    # Fetch data from elf.
    def read
      # refs = []
      # @tbls.each do |k, e|
      #   e.read
      #   e.each_ref do |ref| # Add refered table to refs so that can read it later.
      #     refs << ref unless @tbls.has_value? ref.data
      #     # TODO: redirect the ref to the table which have existed already or write will failed.
      #   end
      # rescue => err
      #   puts "When read #{k}: #{err}"
      #   puts err.backtrace if EIS::Core.eis_debug
      # end
      # until refs.empty? # Read all refered table.
      #   refs.each do |ref| # TODO: make single entry embedded in the ref will makes result easier to read.
      #     @tbls["implicit_#{ref.ref.to_s(16).upcase}"] = ref.data
      #     ref.data.read
      #     ref.data.each_ref do |iref|
      #       refs << iref unless @tbls.has_value? iref.data
      #     end
      #     refs.delete ref
      #   end
      # end
      @table_manager.read
      @permission_man.global_merge
      nil
    end

    def write
      @permission_man.global_merge
      @table_manager.write
      nil
    end

    # def select(name)
    #   @tbls[name]
    # end

    def tables
      @table_manager.tables
    end

    def table_by_id id
      @table_manager.table_by_id id
    end

    def save
      @fiomgr.save
    end

    def load(strict: true)
      @fiomgr.load(true)
    end

    # attr_reader :tbls

    protected

    # def read_tbl(ele)
    # end
  end
end
