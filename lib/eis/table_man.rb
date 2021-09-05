require "eis/table"

module EIS
  class TableMan
    ##
    # The initializer. Needed parameters:
    # * elf_man: to check the elf statement.
    # * perm_man: to handle the permission block.
    #   (When the system is set to aggressive, realloc the table)
    #
    # And these named parameters:
    # * implicit_prefix: auto-renaming, if an implicit table checked, the table will
    #   be named as the prefix with its address. DEFAULT: "implicit_".
    # * enable_rename: if a named table be registered after imlicit asumming, whether
    #   the table's id will be changed. If so, after that, the outer codes need to
    #   requery the name by a table's unchangable properties. DEFAULT: false.
    def initialize elf_man, perm_man, implicit_prefix: "implicit_", enable_rename: false
      @elf_man = elf_man
      @perm_man = perm_man
      @implicit_prefix = implicit_prefix
      @enable_rename = enable_rename
      @tables = []
    end

    def to_s
      <<-EOS
EIS::TableMan to #{@elf_man}. Implicit prefix is #{@implicit_prefix}
#{@tables.size} table(s) is managed.
      EOS
    end

    Cell = Struct.new :name, :table, :type, :ref_cnt

    ##
    # = Register a table to manager
    # This method will register a **created** table to the manager. And
    # by default, this table will be primary type (Can't be shifted).
    #
    # == Parameters
    # +table+:: The table needs to be registered. Must be a instance of
    #           +EIS::Table+.
    # +name+:: The name of the table. If not given, the table will be named
    #          with a specified prefix in initialization and its address
    #          automatically.
    # +type+:: *named* The type of the cell. See the following description.
    #          If this argument is set to +:partial+ or +:single+, which
    #          means that table is already referenced by at least one table,
    #          we set the +ref_cnt+ to +1+ instead of +0+.
    #
    # == Description of Type
    # The parameter 'type' can be one of these posssible pre-defined value:
    # * :primary - The table is primary, it can't be shifted to other
    #   address in any case. The primary table's ref_cnt field means nothing
    #   and will not be update unless the whole table is refered.
    # * :partial - The table is a part of a bigger table. Reffered to the
    #   bigger table and will not be handle during address shifting.
    #   Since :partial is not a real table, the table field is nil. The
    #   record exists just for the convenient management.
    # * :single - The table is implicittly reffered by another table and
    #   it's stand-along. It will be shift if the aggressive shifting
    #   option is specified.
    def register_table table, name = nil, type: :primary
      raise ArgumentError.new("table",
        "Must be EIS::Table but #{table.class}!") unless table.is_a? Table
      cell = Cell.new(name.nil? ? @implicit_prefix + table.location.to_s(16) : name,
        table,
        type,
        type == :primary ? 0 : 1)
      @tables << cell
    end

    def each
      if block_given?
        @tables.each do |table|
          yield table
        end
      end
    end

    def each_primary
      if block_given?
        @tables.each do |table|
          next if table.type != :primary
          yield table
        end
      end
    end

    def each_partial
      if block_given?
        @tables.each do |table|
          next if table.type != :partial
          yield table
        end
      end
    end

    def each_single
      if block_given?
        @tables.each do |table|
          next if table.type != :single
          yield table
        end
      end
    end

    ##
    # = Try to get the specified table
    # Try get a table datum cell. The location, size, and count.
    # The result will be a <tt>EIS::TableMan::Cell</tt> or a nil if not a
    # corresponding table / partial table can be find.
    #
    # If a partial table be the result, the type will be <tt>:partial</tt>
    # and the naming rule is "[Table name]:[Index name]". e.g. "Talk:23".
    # You'd better handle this special case.
    #
    # *This method only check if here is a corresponding record.*
    # 
    # *No changes will be made to this manager.*
    #
    # == Parameters
    # +location+::  The location of where the table begins.
    # +size+::      The size of a single entry in the table.
    #               If the value is -1, routine will ignore this limitation.
    # +count+::     The count of the entries in the table.
    # +is_vma+::    _named_ if the location is the vma or not.
    #               DEFAULT: true.
    def try_get_id location, type, count, is_vma: true
      location = is_vma ? @elf_man.vma_to_loc location : location

      each_single do |entry| # 为已经登记的隐含表
        if entry.location == location &&
            (count == -1 ? true : entry.table.count == count)
          entry.ref_cnt += 1
          return entry.name
        end
      end

      each_partial do |entry| # 乃其他表的引用
        if entry.location == location
          entry.ref_cnt += 1
          return entry.name # partial 的名字在创建时即符合约定
        end
      end

      each_primary do |cell|
        next unless cell.table.type == type # Type mismatch.

        datum = cell.table.datum_by_location(location)
        next if datum.nil? # Nothing is found.
        return cell.name if cell.table.location == location &&
          cell.table.count == count # 必须是显式指定到整个表才是相同。
        
        # 所有判例确认完毕，到达此处者皆为部分引用。
        # 由于已有的部分引用在上表一定命中，此处的引用一定不存在。
        # 根据约定，这里不做任何处理（理论存在，但无法创建记录单元）。

        # return "#{cell.name}:#{datum.index}"
      end
      nil
    end

    def get_id! location, type, count, name: nil, is_vma: true
      location = is_vma ? @elf_man.vma_to_loc location : location

      tblnm = name.nil? @implicit_prefix + location.to_s : name
      id = try_get_id location, type, count
      return id unless id.nil?

      each_primary do |cell|
        next unless cell.table.type == type

        datum = cell.table.datum_by_location(location)
        next if datum.nil?

        # 对于已经存在的表的完全匹配必然已在 try_get_id 中命中并返回。
        # 故此处不必判断是否命中全表，到达此处的必然是部分引用。
        # 所以直接创建记录单元并返回 ID
        @tables << Cell.new(tblnm, nil, :partial, 1)
        return "#{cell.name}:#{datum.index}"
      end
      # 对于到达这里的项，其表一定尚未创建。
      # 故其必为 :single ，创建新的 Table 容纳之，并创建记录单元。
      table = Table.new(location, count, type, @elf_man, is_vma: is_vma)
      @tables << Cell.new(tblnm, table, :single, 1)
      tblnm
    end
  end
end
