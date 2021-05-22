# --- 环境初始化 ---
require './eis/utils'
require 'rexml/document'

$core = EIS::Core.new('SLPS_256.04') # EIS综合管理

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
$core.table('RPKFAT' ,0x354b00 + 0xff000, 2703, FAEntry)
$core.table('IPUs' ,0x5ff920, 361, IPUEntry)
$core.table('BGMs' ,0x503b98 + 0xff000, 122, BGMEntry)
$core.table('MOVs' ,0x504c70 + 0xff000, 104, MOVEntry)
$core.table('Skills' ,0x5d4b98 + 0xff000, 309, SkillEntry)

# --- 导出 ---
$core.read
$core.save