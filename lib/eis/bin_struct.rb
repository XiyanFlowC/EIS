require "eis/types"

module EIS
  ##
  # The basic unit to dear with the exportation and importation
  #
  # = Example
  # <tt>
  # class A < EIS::BinStruct
  #   int8 :test, 4
  #   int16 :limit
  #   ref A, length = 999
  # end
  # </tt>
  # = Remarks
  # The methods used in the declair should be mixin or by other
  # methods to add.
  #
  # If required the utils.rb, int8-64, uint8-64 will be available.
  # The registered method should handle:
  # * name
  # * length
  #
  # and register the id, type and controls (as nil if unused) as a
  # Field into class holds
  class BinStruct
    def initialize
      @fields = {}
      fields_register_table.each do |name, cnt|
        @fields[name] = cnt.type.new(cnt.count, [self] + cnt.control)
      end
    end

    def to_s
      ans = "#{self.class.name} :\n"
      @fields.each do |k, e|
        ans << "#{e.class.name}[#{e.size}] #{k} = #{e.data}\n"
      end
    end

    def size
      ret = 0
      @fields.each do |k, e|
        ret += e.size * e.count
      end

      ret
    end

    def fields
      @fields.dup
    end

    def each_data
      return nil unless block_given?
      @fields.each do |_, entry|
        yield entry
      end
    end

    def each_ref
      return nil unless block_given?
      @fields.each do |_, entry|
        yield entry if entry.is_a? EIS::Ref
      end
    end

    def read(stream)
      # readdelay = [] # 稍后再读取的引用，确保无论数量限制先后，都能正确读取
      @fields.each do |key, entry|
        # readdelay << entry if entry.class == Ref

        entry.read(stream)
      end

      # readdelay.each do |entry|
      #   entry.readref(stream) # 此时再解引用，这时数量限制数据必然已经读入
      # end # 现在暂时不需要。
    end

    def write(stream)
      @fields.each do |key, entry|
        entry.write(stream)
      end
    end

    def fields_register_table
      self.class.fields_register_table
    end

    class << self
      attr_accessor :fields_register_table

      # def elf
      #   EIS::Core.elf
      # end
      # --------------------------------
      # 必须接受两个参数，按照约定，除了 name 以外都是可选的。
      # 第二项必需是数量，此后的选项不做要求，请自行约定。
      # --------------------------------
      types = %w[int8 int16 int32 int64 u_int8 u_int16 u_int32 u_int64]
      types.each do |type|
        define_method :"#{type}" do |name, *params|
          count = handle_count(params)

          register_field(name, count, "EIS::#{type.camelcase}".constantize, [])
        end
      end

      attr_accessor :elf, :string_allocator

      def string(name, *params)
        count = handle_count(params)
        register_field(name, count, EIS::String, [EIS::BinStruct.string_allocator, EIS::BinStruct.elf])
      end

      def ref(type, name, count)
        register_field(name, count, EIS::Ref, [type.to_s.constantize, EIS::BinStruct.elf])
      end

      def handle_count(params)
        return 1 if params.count == 0
        raise ArgumentError.new "count", "count must be a number but #{params[0].class}" if params[0].class != Integer

        params[0]
      end

      def register_field(name, count, type, controls)
        class_eval <<-EOD, __FILE__, __LINE__ + 1
          def #{name}
            @fields["#{name}"].data
          end
  
          def #{name}=(value)
            @fields["#{name}"].data = value
          end
        EOD
        @fields_register_table ||= {}
        @fields_register_table[name.to_s] = Field.new(type, count, controls)
      end
    end
  end
end
