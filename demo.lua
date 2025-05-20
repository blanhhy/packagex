require "packagex".init() -- 完整导入

--[[ 或者延迟导入
local packagex = require "packagex"
packagex.init()]]

-- 单文件导入（不影响主要功能）
-- require "packagex.packagex".init()

from "math": import {"sin", "pi"}
print(sin(pi/2)) -- 1.0

requirex "shell" -- 第三方库

-- shell 不在 _G 中
print(rawget(_G, "shell") or "shell 不在 _G 中")

-- 可以运行，因为全局命名空间扩展
print(shell.ls"sdcard")

include "shell" -- 假如用 include

-- 现在 shell 在 _G 中了
print(rawget(_G, "shell") and "现在 shell 在 _G 中了")

