require "eis/types"

module EIS
  ##
  # A _Struct_ to store the meta data of fields in _BinStruct_
  #
  # = Fields
  # _:type_::   The type of this field
  # _:params::  The parameters that passed by the definating
  #             function.
  Field = Struct.new(:type, :params)

  ##
  # = Binary Structure Managing Centre
  # The basic unit to dear with the exportation and importation.
  # You needn't initial this manually. The +EIS::Table+ is designed
  # to deal with it.
  #
  # This class will be used when every call
  #
  # This class is an interface between data parsers and elfman, so
  # the mess of this class is not a matter. But it is very welcome
  # if you want to optimize the structure.
  #
  # == Example
  #
  #   class A < EIS::BinStruct
  #     int8 :test, 4
  #     int16 :limit
  #     ref A, length = 999
  #   end
  #
  # == Remarks
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
    def initialize svc_hub
      @fields = {}
      fields_register_table.each do |name, cnt|
        # @fields[name] = cnt.type.new(cnt.count, [self] + cnt.control)
        @fields[name] = svc_hub.di cnt.type
        @fields[name].handle_parameter self, *cnt.params
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
        ret += e.size
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
      readdelay = [] # 稍后再读取的引用，确保无论数量限制先后，都能正确读取
      @fields.each do |key, entry|
        readdelay << entry if entry.class.method_defined? :post_proc

        entry.read(stream)
      end

      readdelay.each do |entry|
        entry.post_proc # 此时再解引用，这时数量限制数据必然已经读入
      end
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

      def define_type type_name, type_class
        singleton_class.define_method :"#{type_name}" do |name, *params|
          register_field(name, type_class, params)
        end
      end

      types = %w[int8 int16 int32 int64 u_int8 u_int16 u_int32 u_int64 string]
      types.each do |type|
        BinStruct.define_type type.delete("_"), "EIS::#{type.camelcase}".constantize
      end

      def register_field(name, type, params)
        class_eval <<-EOD, __FILE__, __LINE__ + 1
          def #{name}
            @fields["#{name}"].data
          end
  
          def #{name}=(value)
            @fields["#{name}"].data = value
          end
        EOD
        @fields_register_table ||= {}
        @fields_register_table[name.to_s] = Field.new(type, params)
      end
    end
  end
end
