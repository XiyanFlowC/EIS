require_relative './eis/eis'
require 'rexml/document'

module EIS
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
    def initialize elf_path ,path = nil
      @elf = EIS::ElfMan.new elf_path
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

    def update(name, data)
      @tbls[name].data.each do |e|
        data.each do |key, value|
          e.send("#{key.to_s}=", value)
        end
      end
      @tbls[name]
    end

    ##
    # Fetch data from elf.
    def read()
      @tbls.each do |k,e|
        begin
          e.read
        rescue =>exception
          puts "When read #{k}: #{exception.to_s}"
          puts exception.backtrace if $eis_debug
        end
      end
      @elf.permission_man.global_merge
    end

    def select(name)
      @tbls[name]
    end

    ##
    # Save data to file. 
    def save
      file = File.new @path, 'w'
      doc = REXML::Document.new
      xml = doc.add_element('ELF', {'name'=>@elf.base_stream.path, 'version' => @elf.base_stream.mtime.to_s})

      @tbls.each do |key, value|
        ele = xml.add_element(key, {'type'=>'Table', 'addr'=>value.location.to_s, 'size'=>value.count.to_s})

        do_save(ele, value)
      end

      pm = xml.add_element('PermissiveBlocks', {'type' => 'EISCore', 'count' => @elf.permission_man.registerTable.size})
      @elf.permission_man.registerTable.each do |e|
        entry = pm.add_element('PermissiveBlock')
        entry.add_element('Location', {'base' => '16', 'unit' => 'byte'}).add_text(e.location.to_s(16))
        entry.add_element('Length', {'base' => '10', 'unit' => 'byte'}).add_text(e.length.to_s)
      end

      doc.write file, 2
      file.close
    end

    attr_reader :tbls
    
    protected
    ##
    # Recursive daving routine
    # = Parameters
    # +xml+:: The xml node used by _REXML::Document_
    # +val+:: Value that should be write
    def do_save(xml, val)
      i = 0
      val.data.each do |e|
        entry = xml.add_element(e.class.to_s, {'index' => i.to_s})
        i += 1
        e.fields.each do |k, v|
          f = entry.add_element(k)
          if v.class == Ref
            f.add_attribute('type', 'Ref')
            f.add_attribute('refval', v.ref.to_s(16).upcase)
            f.add_attribute('limiter', v.count.to_s)
            do_save f, v
          elsif v.data.class == Array
            f.add_attribute('type', 'Array')
            f.add_attribute('size', v.data.size.to_s)
            f.add_attribute('base', v.class.to_s)
            v.data.each do |entry|
              f.add_element('entry').add_text(entry.to_s)
            end
          else
            f.add_attribute('type', v.class.to_s)
            f.add_text v.data.to_s
          end
        end
      end
    end
  end
end