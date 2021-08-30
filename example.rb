#!/usr/bin/env ruby
# run this example in development environment: `bundle exec ruby example.rb`
require "eis"
require "pry"

EIS::Core.eis_shift = 1 # 不允许子指针表移位
EIS::Core.eis_debug = true
core = EIS::Core.new("tmp/SLPS_256.04", "tmp/output.elf", fpath: "tmp/jpn.xml") # EIS综合管理
module EIS
  class String
    def data
      @data.force_encoding("sjis").encode("utf-8")
    end

    def data=(val)
      @data = val.encode("sjis")
    end
  end
end

# --- 数据结构定义开始 ---
# 文件分配表项
class FAEntry < EIS::BinStruct
  string :name
  int32 :lba
  int32 :length
end

# IPU 内部描述（游戏不显示，DEBUG 用）
class IPU < EIS::BinStruct
  string :path, 1
  string :desc, 1
end

# BGM 项（游戏显示，注意表间关系）
class BGM < EIS::BinStruct
  string :code
  string :name
end

# 视频及其控制相关属性（游戏显示，注意表间关系）
class Movie < EIS::BinStruct
  string :path
  int16 :param, 6
  string :name
end

# 技能表，含技能数据，建议研究（MOD 制作可能）
class Skill < EIS::BinStruct
  string :name
  string :name2
  int16 :params, 6
  string :memo
end

# 对话项
class Dialog < EIS::BinStruct
  int32 :style
  int32 :narrator
  int32 :portrait
  int32 :id
  int16 :portraitDiff
  int16 :data
  string :text
end

# 对话索引项，ELF 中对话基本由此索引
class DLGIndex < EIS::BinStruct
  int32 :count
  ref :Dialog, :dest, :count
end

# 文件包内容索引
class FPEntry < EIS::BinStruct
  string :name
  ref :FAEntry, :files, :count
  int32 :count
end

# EVD 内部描述（不显示，DEBUG 用）
class EVDMemo < EIS::BinStruct
  int32 :grp # 组序号（快速定界用？）
  string :code # 内部代号
  string :desc # 说明
end

class RecipeCard < EIS::BinStruct
  string :name
  int32 :ukn
  int32 :picid
  string :cardName
end

class MonsterCard < EIS::BinStruct
  string :name
  int32 :ukn
  int32 :picid
  string :description
  string :cardName
  string :place
end

# --- 导出表指定开始 ---
# core.table('RPKFAT' ,0x2E7D80 + 0xff000, 2805, FAEntry) # 低价值
# core.table('FPFAT', 0x30ADA8 + 0xff000, 671, FPEntry) # 低价值（改文件名时或许有用？）
core.table("EVDs", 0x638df0 + 0xff000, 976, EVDMemo)
core.table("IPUs", 0x58e060, 361, IPU)
core.table("BGMs", 0x5911c8, 122, BGM)
core.table("MOVs", 0x5922a0, 104, Movie)
core.table("Skills", 0x6e64a0, 309, Skill)
core.table("RCs", 0x6eab18, 108, RecipeCard)
core.table("MCs", 0x6eb1d8, 124, MonsterCard)

core.table("CosmoSphereDialogs", 0x721478, 46, DLGIndex)
core.table("InstallDialogs", 0x724060, 68, DLGIndex)
core.table("NightDialogs", 0x734d20, 254, DLGIndex)
core.table("NightGreetDialogs", 0x735888, 37, DLGIndex)
# core.table('SingleDialogs', 0x832088, 9999, DLGIndex) # ？

core.table("GrathmelcDialogs", 0x8bb8d8, 137, DLGIndex)

# --- 导出 ---
core.read
core.save
