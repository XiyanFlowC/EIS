# --- 环境初始化 ---
require './eis/utils'
require 'rexml/document'

elf = EIS::ElfMan.new(File.new('SLPS_256.04', 'rb')) # elf综合管理

EIS::BinStruct.init(elf) # 所有依托elf之结构首先初始化

# --- 数据结构定义开始 ---
class FAEntry < EIS::BinStruct
  int32 :lba
  int32 :length
  string :name
end

class IPUEntry < EIS::BinStruct
  string :path, 1
  string :desc, 1
end

class BGMEntry < EIS::BinStruct
  string :code
  string :name
end

class MOVEntry < EIS::BinStruct
  string :path
  int16  :param, 6
  string :name
end

class SkillEntry < EIS::BinStruct
  string :name
  string :name2
  int16  :params, 6
  string :memo
end

class DialogEntry < EIS::BinStruct
  int32 :data, 5
  string :text
end

class CSDLG < EIS::BinStruct
  int32 :length
  ref :DialogEntry, :dest, :length
end

# --- 导出表指定开始 ---
rpkfat = elf.new_table(0x354b00 + 0xff000, 2703, FAEntry)
ipus = elf.new_table(0x5ff920, 361, IPUEntry)
bgms = elf.new_table(0x503b98 + 0xff000, 122, BGMEntry)
movs = elf.new_table(0x504c70 + 0xff000, 104, MOVEntry)
skills = elf.new_table(0x5d4b98 + 0xff000, 309, SkillEntry)

# --- 导出 ---
# output = File.new('at_debug.xml', 'w') # 输出文件
# xmldoc = REXML::Document.new
# xml = xmldoc.add_element('ELF', {'name' => 'SLPS_256.04'})

# ipux = xml.add_element('IPUs', {'addr' => ipus.location, 'count' => ipus.count})
# ipus.read do |e|
#   ex = ipux.add_element('IPU')
#   ex.add_element('path').add_text(e.path.force_encoding('sjis').encode('utf-8'))
#   ex.add_element('description').add_text(e.desc.force_encoding('sjis').encode('utf-8'))
# end

# rpkfatx = xml.add_element('RPKFAT', {'addr' => rpkfat.location, 'count' => rpkfat.count})
# rpkfat.read do |e|
#   ex = rpkfatx.add_element('File')
#   ex.add_element('LBA').add_text(e.lba[0].to_s)
#   ex.add_element('size').add_text(e.length[0].to_s)
#   ex.add_element('name').add_text(e.name.force_encoding('sjis').encode('utf-8'))
# end

# bgms.read do |e|
#   output.write("#{e.code},#{e.name.force_encoding('sjis').encode('utf-8')}\n")
# end

# movs.read do |e|
#   output.write "#{e.path},#{e.param},#{e.name.force_encoding('sjis').encode('utf-8')}\n"
# end

# skills.read do |e|
#   output.write "#{e.name.force_encoding('sjis').encode('utf-8')},#{e.name2.force_encoding('sjis').encode('utf-8')},#{e.memo.force_encoding('sjis').encode('utf-8')},#{e.params}\n"
# end

# xmldoc.write output, 2
# output.close