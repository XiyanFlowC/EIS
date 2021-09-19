module EIS
  module NumericDataAccess
    def data
      return @data[0] if @data.instance_of?(Array) && @data.size == 1

      @data
    end

    def data=(val)
      @data = if val.is_a? Numeric
        [val]
      elsif val.is_a? ::String
        [val.to_i]
      else
        val
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
      stream.syswrite(@data.pack("c#{@data.count}"))
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
      @data = stream.sysread(@count).unpack("C#{@count}")
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
      @data = stream.sysread(2 * @count).unpack("S#{@count}")
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
      @data = stream.sysread(4 * @count).unpack("L#{@count}")
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
    class << self
      attr_accessor :align
      String.align = 8
    end

    ##
    # 初始化+String+对象，需要计数和控制数组
    #
    # = 参数
    # +count+::  指向字符串指针的数量
    # +controls+:: 指定布局为，1: 容许段管理器; 2: elf管理器（解引用）
    def initialize(count, controls)
      if count != 1
        raise ArgumentError("count",
          "Can't load more than 1 string in only one EIS::String")
      end

      @count = count
      @perm = controls[1]
      @elf = controls[2]
      @shiftable = controls[3]
    end

    attr_accessor :data, :ref, :shiftable

    def read(stream)
      puts "geting string pointer at #{stream.pos.to_s(16)}" if EIS::Core.eis_debug
      # refs = stream.sysread(4 * @count).unpack("L#{@count}")
      @ref = stream.sysread(4).unpack1("L")

      # if refs[0] == 0
      if @ref == 0
        @data = "(null)"
        return
      end

      oloc = stream.pos
      # refs.each do |e|
      loc = @elf.vma_to_loc(@ref)
      raise RangeError.new("vma out of range") if loc.nil?
      stream.seek loc
      @data = fetch_string(stream)
      if @shiftable && EIS::Core.eis_shift >= 1
        @perm.register(loc, @data, align: @elf.align(loc, is_vma: false)) # 可移动者
      # else
      #   @perm.assign(loc, @data, align: @elf.align(loc, is_vma: false))
      end
      # end

      stream.pos = oloc
    end

    def write(stream)
      if @data == "(null)"
        # refs = [0]
        @ref = 0
        stream.syswrite(refs.pack("L"))
        return
      end

      refs = []
      oloc = stream.pos
      # @data.each do |s|
      if EIS::Core.eis_shift >= 1 && @shiftable
        loc = @perm.salloc(@data, align: EIS::String.align) 
        raise "Memory run out when alloc #{@data}" if loc.nil?
      else
        loc = @elf.vma_to_loc(@ref)
        raise "Specified ref value is not included by file." if loc.nil?
      end

      refs << @elf.loc_to_vma(loc)
      stream.pos = loc
      write_string stream, @data
      # end
      stream.pos = oloc
      stream.syswrite(refs.pack("L#{@count}"))
    end

    def size
      @count * 4
    end

    protected

    def fetch_string(stream)
      puts "fetching string at #{stream.pos.to_s(16)}" if EIS::Core.eis_debug
      ret = ""
      ch = stream.sysread(1)
      while ch != "\0"
        ret << ch
        ch = stream.sysread(1)
      end
      ret
    end

    def write_string(stream, s)
      p = (s.length + EIS::String.align & ~(EIS::String.align - 1)) - s.length
      stream.syswrite(s)
      stream.syswrite("\0")
      stream.pos += p
    end
  end
end
