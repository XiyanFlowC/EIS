require_relative './eis/utils'
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
          puts exception.to_s
          puts "When read #{k}."
        end
      end
      @elf.permission_man.global_merge
    end

    def select(name, condition)
      tmp = []

      @tbls[name].data do |e|
        tmp << e if condition.call(e)
      end

      tmp.each {|e| yield(e)} if block_given?

      tmp
    end

    def save
      file = File.new @path, 'w'
      doc = REXML::Document.new
      xml = doc.add_element('ELF', {'name'=>@elf.base_stream.path, 'version' => @elf.base_stream.mtime.to_s})

      @tbls.each do |key, value|
        ele = xml.add_element(key, {'addr'=>value.location.to_s, 'size'=>value.count.to_s})

        value.data.each do |e|
          e.fields.each do |k, v|
            f = ele.add_element(k)
            if v.class == Ref
              do_save f, v
            else
              f.add_text v.data.to_s
            end
          end
        end
      end

      doc.write file, 2
      file.close
    end

    attr_reader :tbls
    
    protected
    def do_save(xml, val)
      xml.add_attributes({'type' => 'ref', 'count' => val.data.size})
      i = 0
      val.data.each do |e|
        entry = xml.add_element('entry', {'index' => i.to_s})
        i += 1
        e.fields.each do |k, v|
          f = entry.add_element(k)
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