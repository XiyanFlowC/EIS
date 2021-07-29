require "rexml/document"

require "eis/bin_struct"
require "eis/elf_man"
require "eis/error"
require "eis/permissive_block"
require "eis/permissive_man"
require "eis/ref"
require "eis/string_allocator"
require "eis/symbol_man"
require "eis/utils"

module EIS
  @eis_shift = 1 # the shift aggressively 0 none, 1 str, 2 ptr
  # 请不要设为2，激进的指针重整策略现在暂不可用
  @eis_debug = nil
  class << self
    attr_accessor :eis_shift, :eis_debug
  end

  ##
  # A _Struct_ to store the meta data of fields in _BinStruct_
  #
  # = Fields
  # _:id_::     The appear sort of this field
  # _:type_::   The type of this field
  Field = Struct.new(:type, :count, :control)

  ##
  # = Exporting and Importing Core Class
  # Provides an easy way to initialize the EIS environmet.
  # Also provides a way to save and load to/from files so that
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
    def initialize(elf_path, path = nil, target_elf = "output.elf")
      File.new(target_elf, "w").close unless File.exist? target_elf
      @elf = EIS::ElfMan.new elf_path
      @out_elf = File.new(target_elf, "r+b")
      EIS::BinStruct.init(@elf)
      @path = path
      @tbls = Hash.new nil
    end

    ##
    # Declare a new table
    #
    # = Parameters
    # * _name_: table's name.
    # * _location_: table's start memory address.
    # * _length_: the count of entries in the table.
    # * _type_: the entries' type.
    def table(name, location, length, type)
      @tbls[name.to_s] = @elf.new_table(location, length, type)
    end

    ##
    # Fetch data from elf.
    def read
      @tbls.each do |k, e|
        e.read
      rescue => e
        puts "When read #{k}: #{e}"
        puts e.backtrace if EIS::Core.eis_debug
      end
      @elf.permission_man.global_merge
    end

    def select(name)
      @tbls[name]
    end

    ##
    # Save data to file.
    def save
      file = File.new @path, "w"
      doc = REXML::Document.new
      xml = doc.add_element("ELF", {"name" => @elf.base_stream.path, "version" => @elf.base_stream.mtime.to_s}) # root element

      @tbls.each do |key, value| # save all tables
        ele = xml.add_element(key, {"type" => "Table", "addr" => value.location.to_s, "size" => value.count.to_s})

        do_save(ele, value)
      end

      # save permission data
      pm = xml.add_element("PermissiveBlocks", {"type" => "EISCore", "count" => @elf.permission_man.register_table.size})
      @elf.permission_man.register_table.each do |e|
        entry = pm.add_element("PermissiveBlock")
        entry.add_element("Location", {"base" => "16", "unit" => "byte"}).add_text(e.location.to_s(16))
        entry.add_element("Length", {"base" => "10", "unit" => "byte"}).add_text(e.length.to_s)
      end

      doc.write file, 2
      file.close
    end

    def load(mode: "r", strict: true)
      doc = REXML::Document.new(File.new(@path, mode))

      root = doc.root
      if root.attributes["version"] != @elf.base_stream.mtime.to_s # base elf version mismatch
        warn "WARN: The version of elf against the version of knowledge base"
        return nil if strict
      end

      if root.attributes["name"] != @elf.base_stream.path
        warn "WARN: Filenames mismatch."
        return nil if strict
      end

      root.each_element_with_attribute("type", "Table") do |ele| # load for tables
        tbl = select(ele.name)
        data = []
        ele.elements.each do |e| # entries in table
          cnt = Module.const_get(e.name).new
          e.elements.each do |fld| # every fileds
            if fld.attributes["type"] == "Array"
              tmp = []
              fld.each_element do |entry|
                if fld["base"].include? "Int"
                  tmp << entry.text.splite.to_i
                else
                  raise "FIXME: Not Implement Yet"
                end
              end
              cnt.send("#{fld.name}=", tmp)
            elsif fld.attributes["type"] == "Ref"
              cnt.send("#{fld.name}=", fld.text.strip.to_i(16))
            else
              cnt.send("#{fld.name}=", fld.text.strip)
            end
          end
          data << cnt
        end
        tbl.data = data
      end
    end

    attr_reader :tbls

    protected

    def read_tbl(ele)
    end

    ##
    # Recursive daving routine
    # = Parameters
    # +xml+:: The xml node used by _REXML::Document_
    # +val+:: Value that should be write
    def do_save(xml, val)
      i = 0
      return nil if val.data.nil?

      val.data.each do |e|
        entry = xml.add_element(e.class.to_s, {"index" => i.to_s})
        i += 1
        e.fields.each do |k, v|
          f = entry.add_element(k)
          if v.instance_of?(Ref)
            f.add_attribute("type", "Ref")
            # f.add_attribute('refval', v.ref.to_s(16).upcase)
            f.add_attribute("limiter", v.count.to_s)
            f.add_text v.data.to_s(16)
            # do_save f, v
          elsif v.data.instance_of?(Array)
            f.add_attribute("type", "Array")
            f.add_attribute("size", v.data.size.to_s)
            f.add_attribute("base", v.class.to_s)
            v.data.each do |entry1|
              f.add_element("entry").add_text(entry1.to_s)
            end
          else
            f.add_attribute("type", v.class.to_s)
            f.add_text v.data.to_s
          end
        end
      end
    end
  end
end
