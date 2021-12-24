require "eis/bin_struct"

module EIS
  ##
  # Pointer deref, co-operate with BinStruct, Core, Table
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
    def initialize(elf_man, table_man)
      @elf_man = elf_man
      @tbl_man = table_man
    end

    def handle_parameter bin_struct, type, limiter = -1
      @type = type
      @limiter = limiter
      @limit = count.instance_of?(Symbol) ? bin_struct.method(count) : -> { count }
    end

    def size
      4
    end

    def count
      1
    end

    attr_reader :limiter
    attr_accessor :data

    def ref
      @elf_man.loc_to_vma @data.type == :partial ? @data.table : @data.table.location
    end

    def ref= val
      @data.table.change_loc! val
    end

    ##
    # Read from stream
    def read(stream)
      # @data = []
      @ref = stream.sysread(4).unpack1("L<") if @elf_man.elf_base.endian == :little
      @ref = stream.sysread(4).unpack1("L>") if @elf_man.elf_base.endian == :big
      puts("Ref#read(): @ref = #{@ref}") if EIS::Core.eis_debug
      # id = @tbl_man.get_id! @ref, @type, @limit.call # can't be done here
      # @data = @tbl_man.cell_by_id id # the limiter can still not readin
      # @data = Table.new(@ref, @limit.call, @type, @elf_man, is_vma: true)
    end

    def post_proc
      id = @tbl_man.ref_get_id! @ref, @type, @limit.call
      @data = @tbl_man.cell_by_id id
    end

    def write(stream)
      loc = ref # 获取原始位置
      # loc = @elf_man.permission_man.alloc(@data.size * @data[0].size) if $eis_shift >= 2 # 激进的指针重整策略需要重新分配指针表空间
      # raise "Virtual memory run out" if loc.nil?
      rloc = [loc].pack("L<") if @elf_man.elf_base.endian == :little
      rloc = [loc].pack("L>") if @elf_man.elf_base.endian == :big
      stream.syswrite(rloc)
      nloc = stream.pos # 保存当前流位置，避免后续读取／写入混乱

      # @data.write stream # Leave these to TableMan
      # stream.seek loc
      # @data.each do |entry|
      #   entry.write(stream)
      # end

      stream.seek nloc # 恢复流位置
    end
  end

  EIS::BinStruct.define_type "ref", EIS::Ref
end
