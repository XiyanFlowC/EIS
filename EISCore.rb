require_relative './eis/eis'
require 'rexml/document'

module EIS
  class Core
    def initialize elf_path ,path = nil
      @elf = EIS::ElfMan.new elf_path
      EIS::BinStruct.init(@elf)
      @path = path
      @tbls = Hash.new nil
    end

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

    def save
      file = File.new @path, 'w'
      doc = REXML::Document.new
      xml = doc.add_element('ELF', {'name'=>@elf.base_stream.path, 'version' => @elf.base_stream.mtime.to_s})

      @tbls.each do |key, value|
        ele = xml.add_element(key, {'addr'=>value.location.to_s, 'size'=>value.count.to_s})

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
    def do_save(xml, val)
      i = 0
      val.data.each do |e|
        entry = xml.add_element(e.class.to_s, {'index' => i.to_s})
        i += 1
        e.fields.each do |k, v|
          f = entry.add_element(k, {'type' => v.class.to_s})
          if v.class == Ref
            do_save f, v
          else
            f.add_text v.data.to_s
          end
        end
      end
    end
  end
end