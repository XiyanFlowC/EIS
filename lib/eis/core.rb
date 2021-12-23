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
require "eis/svc_hub"

require "eis/filesrv/xmlio"

module EIS
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
      attr_accessor :eis_shift, :eis_debug
    end

    def initialize(elf_path, target_elf = "output.elf", fpath: nil, fiomgr: EIS::XMLIO)
      # File.new(target_elf, "w").close unless File.exist? target_elf
      @elf = EIS::ElfMan.new elf_path
      @elf.elf_out = @out_elf = File.new(target_elf, "r+b")
      warn "File length wierd!" if @out_elf.size != @elf.base_stream.size

      @svc_hub = SvcHub.new
      @svc_hub.register_service @elf
      @permission_man = @svc_hub.acsvc PermissiveMan
      @string_allocator = @svc_hub.acsvc StringAllocator
      @table_manager = @svc_hub.acsvc TableMan

      @fiomgr = fiomgr.new @elf, @table_manager, @permission_man, fpath unless fpath.nil?
    end

    attr_reader :svc_hub

    ##
    # Declare a new table
    #
    # = Parameters
    # +name+:: table's name.
    # +location+:: table's start memory address.
    # +length+:: the count of entries in the table.
    # +type+:: the entries' type.
    def table(name, location, length, type)
      tbl = Table.new(location, length, type, @svc_hub)
      @table_manager.register_table(tbl, name)
      tbl
    end

    ##
    # Fetch data from elf.
    def read
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
