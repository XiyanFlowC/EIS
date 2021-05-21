require './eis/utils'
require 'rexml/document'

def elf_in path
  $core_elf = EIS::ElfMan.new(path)
  EIS::BinStruct.init($core_elf)
end

def elf_out path
  $core_elf.elf_out = File.new(path, 'wb')
end

class DataFile
  def initialize path
    @path = path
  end
end