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
    def initialize(count, controls)
      @type = controls[1]
      @limiter = count
      @limit = count.instance_of?(Symbol) ? controls[0].method(count) : -> { count }
      @elf_man = controls[2]
      @tbl_man = controls[3]
    end

    def size
      4
    end

    def count
      1
    end

    attr_reader :limiter
    attr_accessor :data # , :ref # , :count # , :ref

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
      loc = ref # 获取原始位置
      # loc = @elf_man.permission_man.alloc(@data.size * @data[0].size) if $eis_shift >= 2 # 激进的指针重整策略需要重新分配指针表空间
      # raise "Virtual memory run out" if loc.nil?
      rloc = [loc].pack("L<")[0] if @elf_man.elf_base.endian == :little
      rloc = [loc].pack("L>")[0] if @elf_man.elf_base.endian == :big
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
end
