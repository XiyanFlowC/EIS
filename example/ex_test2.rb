# 在这个例子里，我们展示了如何定义一个结构体并导出。
require "eis"
require "pry"

EIS::Core.eis_debug = true # 如果需要检查 EIS 是否正常工作
core = EIS::Core.new("example/test", "example/output", fpath: "example/ex_path1.xml")
EIS::String.align = 1
# 逆向 ELF 得出：
# 我们发现 string 并没有对齐，预设的 8 在此不适用。
# 然而，由于部分区段依然对齐，这个可以不写。
# 因为重叠是被接受的。（不对齐的区段的可用空间和后方区段重叠，但无伤大雅。区段尾总是对齐所以没关系）
# 但是，导入时，这个必须加上，否则空间将大为缩小。

# BinStruct 为框架所用。即使是普通数组，这里也必须这样。
class NameSingle < EIS::BinStruct
  string :name
end

class Dialog < EIS::BinStruct
  int32 :ppl
  string :msg
end

class RefIdx < EIS::BinStruct
  int8 :name, 32
  int32 :sta
  int32 :end
  ref :dialog, Dialog # 这里定义了到其他表的引用。像这样写就好。注意被引用的表必须先于此表声明
end

core.table("Narrators", 0x3020, 15, NameSingle) # 注意这里是内存地址，因为如果不是内存地址你压根用不到这套系统
# core.table("TalkData", 0x3280, 9999, Dialog) # 不清楚具体数量时可以如此写
# 这样，就有异常 Table#read(): fatal: pointer error. @36 (RuntimeError) 于是就可以改成
core.table("TalkData", 0x3280, 36, Dialog) # 被引用的表
core.table("TalkIdx", 0x3060, 12, RefIdx) # dialog 字段解析时将命中 TalkData 并被自动设置

# core.read # 按注册的读取
# # binding.pry # 如果需要检查
# core.save # 按读取的保存到文件

core.load # 载入文件
# # binding.pry
core.write # 写入 ELF
