require_relative 'basic.rb'

module EIS
  module NumericDataAccess
    def data
      return @data[0] if @data.class == Array && @data.size == 1
      @data
    end

    def data=(val)
      if val.is_a? Numeric
        @data = [val]
      else
        @data = val
      end
    end
  end

  # ================================
  # 解析８位整型数据
  # ================================
  class Int8
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      @data = stream.sysread(@count).unpack("c#{@count}")
    end

    def write(stream)
      stream.syswrite(value.pack("c#{@data.count}"))
    end

    def size
      @count
    end
  end

  # ================================
  # 解析１６位整型数据
  # ================================
  class Int16
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      @data = stream.sysread(2 * @count).unpack("s#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("s#{@data.count}"))
    end

    def size
      @count * 2
    end
  end

  class Int32
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      @data = stream.sysread(4 * @count).unpack("l#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("l#{@data.count}"))
    end

    def size
      @count * 4
    end
  end

  class Int64
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      @data = stream.sysread(8 * @count).unpack("q#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("q#{@data.count}"))
    end

    def size
      @count * 8
    end
  end

  class UInt8
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      stream.sysread(@count).unpack("C#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("C#{@count}"))
    end

    def size
      @count
    end
  end

  class UInt16
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      stream.sysread(2 * @count).unpack("S#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("S#{@count}"))
    end

    def size
      @count * 2
    end
  end

  class UInt32
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      stream.sysread(4 * @count).unpack("L#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("L#{@count}"))
    end

    def size
      @count * 4
    end
  end

  class UInt64
    def initialize(count, _)
      @count = count
    end

    include NumericDataAccess

    def read(stream)
      @data = stream.sysread(8 * @count).unpack("Q#{@count}")
    end

    def write(stream)
      stream.syswrite(@data.pack("@#{@count}"))
    end

    def size
      @count * 8
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
    # +controls+:: 指定布局为，1: 容许段管理器; 2: elf管理器（解引用）
    def initialize(count, controls)
      @count = count
      @perm = controls[1]
      @elf = controls[2]
    end

    attr_accessor :data

    def read(stream)
      refs = stream.sysread(4 * @count).unpack("L#{@count}")

      oloc = stream.pos
      refs.each do |e|
        loc = @elf.vma_to_loc(e)
        stream.seek loc
        @data = fetch_string(stream)# FIXME: @data 应该是一个数组
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

    def size
      @count * 4
    end

    protected
    def fetch_string(stream)
      puts "fetching string at #{stream.pos.to_s(16)}" if $eis_debug
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