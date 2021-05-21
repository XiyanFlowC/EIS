require_relative 'basic.rb'

module EIS
  # ================================
  # 解析８位整型数据
  # ================================
  class Int8
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      @data = stream.sysread(@count).unpack("c#{@count}")
    end

    def write(stream)
      stream.syswrite(value.pack("c#{@data.count}"))
    end
  end

  # ================================
  # 解析１６位整型数据
  # ================================
  class Int16
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      @data = stream.sysread(2 * @count).unpack("s#{@count}")
    end

    def self.write(stream)
      stream.syswrite(@data.pack("s#{@data.count}"))
    end
  end

  class Int32
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      @data = stream.sysread(4 * @count).unpack("l#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("l#{@data.count}"))
    end
  end

  class Int64
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      @data = stream.sysread(8 * @count).unpack("q#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("q#{@data.count}"))
    end
  end

  class UInt8
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      stream.sysread(@count).unpack("C#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("C#{@count}"))
    end
  end

  class UInt16
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      stream.sysread(2 * @count).unpack("S#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("S#{@count}"))
    end
  end

  class UInt32
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      stream.sysread(4 * @count).unpack("L#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("L#{@count}"))
    end
  end

  class UInt64
    def initialize(count, _)
      @count = count
    end

    attr_accessor :data

    def read(stream)
      @data = stream.sysread(8 * @count).unpack("Q#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("@#{@count}"))
    end
  end

  class Ref
    ##
    # Create a new Ref type. 
    #
    # = Parameters
    # * count: The pointers array's 
    # * controls: See the following section
    #
    # = Controls
    # * <tt>controls[0]</tt> The type that this ref point to
    # * <tt>controls[1]</tt> The _ElfMan_ (for vma-loc calc)
    def initialize(count, controls)
      @type = controls[0]
      @limit = count
      @elf_man = controls[1]
    end

    attr_accessor :data

    ##
    # Read from stream
    def read(stream)
      @data = []
      @ref = stream.sysread(4).unpack("L<")[0] if @elf_man.elf_base.endian == :little
      @ref = stream.sysread(4).unpack("L>")[0] if @elf_man.elf_base.endian == :big

      ploc = stream.pos
      puts("Ref#read(): @ref = #{@ref}") if $eis_debug
      # 为读取到的指针解引用。
      loc = @elf_man.vma_to_loc @ref # 解引用 
        
      # 寻址到对应位置，准备载入。
      # --------------------------------
      stream.seek loc

      i = 0
      @limit.times do
        tmp = @type.new
        begin
          tmp.read(stream) # 载入
        rescue Errno::EINVAL
          puts "Ref#read(): fatal: seek failed. @#{i}"
          stream.seek ploc
          return
        end
        puts("Ref#read(): read[#{i}] #{tmp}") if $eis_debug
        i += 1
        @data << tmp # 加入数据数组
      end

      stream.seek ploc
    end

    def write(stream)
      nloc = stream.pos

      loc = @elf_man.vma_to_loc @ref
      stream.seek loc
      @data.each do |entry|
        entry.write(stream)
      end

      stream.seek nloc
    end
  end

  # ================================
  # 指向 C 风格字符串的指针。
  # ================================
  class String
    ##
    # 初始化+String+对象，需要计数和控制数组
    #
    # = 参数
    # +count+::  指向字符串指针的数量
    # +controls+:: 指定布局为，0: 容许段管理器; 1: elf管理器（解引用）
    def initialize(count, controls)
      @count = count
      @perm = controls[0]
      @elf = controls[1]
    end

    attr_accessor :data

    def read(stream)
      refs = stream.sysread(4 * @count).unpack("L#{@count}")

      oloc = stream.pos
      refs.each do |e|
        loc = @elf.vma_to_loc(e)
        stream.seek loc
        @data = fetch_string(stream)
        @perm.register(loc, @data)
      end
      stream.pos = oloc
    end

    def write(stream)
      refs = []
      oloc = stream.pos
      @data.each do |s|
        loc = @perm.salloc(s)
        raise "Memory run out" if loc.nil?
        refs << @elf.loc_to_vma(loc)
        stream.loc = loc
        write_string stream, s
      end
      stream.pos = oloc
      stream.syswrite(refs.pack("L#{@count}"))
    end

    protected
    def fetch_string(stream)
      ret = ''
      ch = stream.sysread(1)
      while ch != "\0"
        ret << ch
        ch = stream.sysread(1)
      end
      return ret
    end

    def write_string(stream, s)
      p = (s.length + 8 & ~7) - s.length
      stream.syswrite(s)
      stream.syswrite('\0')
      stream.pos += p
    end
  end

  class BinStruct

    # ================================
    # 注册到声明式ＡＰＩ
    # ================================
    class << self
      # --------------------------------
      # 必须接受两个参数，按照约定，除了 name 以外都是可选的。
      # 第二项必需是数量，此后的选项不做要求，请自行约定。
      # --------------------------------
      def int8(name, *params)
        count = handle_count(params)
        
        register_field(name, count, Int8, [])
      end

      def int16(name, *params)
        count = handle_count(params)

        register_field(name, count, Int16, [])
      end

      def int32(name, *params)
        count = handle_count(params)

        register_field(name, count, Int32, [])
      end

      def int64(name, *params)
        count = handle_count(params)

        register_field(name, count, Int64, [])
      end

      def uint8(name, *params)
        count = handle_count(params)

        register_field(name, count, UInt8, [])
      end

      def uint16(name, *params)
        count = handle_count(params)

        register_field(name, count, UInt16, [])
      end

      def uint32(name, *params)
        count = handle_count(params)

        register_field(name, count, UInt32, [])
      end

      def uint64(name, *params)
        count = handle_count(params)

        register_field(name, count, UInt64, [])
      end

      def ref(type, name, count)
        register_field(name, count, Ref, [@@types[type.to_s], @@elf])
      end

      def string(name, *params)
        count = handle_count(params)
        register_field(name, count, String, [@@elf.string_alloc, @@elf])
      end

      def register_field name, count, type, controls
        self.class_eval <<-EOD
        def #{name}
          @fields["#{name.to_s}"].data
        end

        def #{name}=(value)
          @fields["#{name.to_s}"].data = value
        end
        EOD

        self.fieldsRegisterTable[name.to_s] = Field.new(type, count, controls)
      end

      def handle_count params
        return 1 if params.count == 0
        raise ArgumentError.new 'count', "count must be a number but #{params[0].class}" if params[0].class != Integer
        params[0]
      end

      def new_child
        ret = Class.new EIS::ElfMan
        ret.class_variable_set '@@fieldsRegisterTable', Hash.new
        ret
      end
    end
  end
end