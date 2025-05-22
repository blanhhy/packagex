-- 完整导入
local packagex = require "packagex"
packagex.init() -- 延迟初始化
packagex.extns.init() -- 启用全局命名空间扩展（可选）

-- 或者连贯进行
-- require "packagex".init()

-- 单文件导入
-- 轻量或兼容模式（主模块是平台无关的）
-- require "packagex.packagex".init()

from "math": import {"sin", "pi"}
print(sin(pi/2)) -- 1.0

requirex "shell" -- requirex 会为模块分配 env

-- shell 不在 _G 中
print(rawget(_G, "shell") or "shell 不在 _G 中")

-- 可以运行，因为《全局命名空间扩展》机制
print(shell.ls"sdcard")

include "shell" -- 假如用 include

-- 现在 shell 在 _G 中了
print(rawget(_G, "shell") and "现在 shell 在 _G 中了")
