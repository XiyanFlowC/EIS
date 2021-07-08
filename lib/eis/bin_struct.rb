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
  # and register the id, type and controls (as nil if unused) as a
  # Field into class holds
  class BinStruct
    @@types = Hash.new nil

    ##
    # Initializae of this basic
    def self.init(elf)
      @@elf = elf
    end

    def self.ref(type, name, count)
      register_field(name, count, Ref, [@@types[type.to_s], @@elf])
    end

    def self.inherited(child)
      @@types[child.to_s] = child # register claimed types, so that the other children can find each other
      child.class_variable_set "@@fieldsRegisterTable", Hash.new(nil) # this val shouldn't impact the parent
      # child.class_variable_set '@@elf', @@elf
      child.class_eval <<-EOD, __FILE__, __LINE__ + 1
        def initialize
          @fields = Hash.new
          @@fieldsRegisterTable.each do |name, cnt|
            @fields[name] = cnt.type.new(cnt.count, [self] + cnt.control)
          end
        end
  
        def size
          ret = 0
          @fields.each do |k,e|
            ret += e.size
          end
  
          ret
        end
  
        def self.elf
          @@elf
        end
  
        def fields
          @fields.dup
        end
  
        def self.fieldsRegisterTable
          @@fieldsRegisterTable
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
      EOD
    end
  end
end
