# --- 环境初始化 ---
require './eis/utils.rb'

elf = EIS::ElfMan.new(File.new('SLPS_256.04', 'rb')) # elf综合管理

EIS::BinStruct.init(elf) # 所有依托elf之结构首先初始化

# --- 数据结构定义开始 ---
class IPUEntry < EIS::BinStruct
  string :path, 1
  string :desc, 1
end

class BGMEntry < EIS::BinStruct
  string :code
  string :name
end

# --- 导出表指定开始 ---
ipus = elf.new_table(0x5ff920, 361, IPUEntry)
bgms = elf.new_table(0x503b98 + 0xff000, 122, BGMEntry)

# --- 导出 ---
output = File.new('extxt.txt', 'w') # 输出文件

ipus.read do |e|
  output.write("#{e.path},#{e.desc.force_encoding('sjis').encode('utf-8')}\n")
end

bgms.read do |e|
  output.write("#{e.code},#{e.name.force_encoding('sjis').encode('utf-8')}\n")
end