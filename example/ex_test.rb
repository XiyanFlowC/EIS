# 在这个例子里，我们展示了如何定义一个结构体并导出。
require "eis"
require "pry"

EIS::Core.eis_debug = true # 如果需要检查 EIS 是否正常工作
core = EIS::Core.new("example/test", "example/output", fpath: "example/ex_path1.xml")
EIS::String.align = 1 # 我们发现 string 并没有对齐，预设的 8 在此不适用

# BinStruct 为框架所用。即使是普通数组，这里也必须这样。
class NameSingle < EIS::BinStruct
  string :name
end

class Dialog < EIS::BinStruct
  int32 :ppl
  string :msg
end

core.table("Narrators", 0x3020, 15, NameSingle) # 注意这里是内存地址，因为如果不是内存地址你压根用不到这套系统
# core.table("TalkData", 0x3280, 9999, Dialog) # 不清楚具体数量时可以如此写
# 这样，就有异常 Table#read(): fatal: pointer error. @36 (RuntimeError) 于是就可以改成
core.table("TalkData", 0x3280, 36, Dialog)

core.read # 按注册的读取
# binding.pry # 如果需要检查
core.save # 按读取的保存到文件

# core.load # 载入文件
# core.write # 写入 ELF
