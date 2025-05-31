local __name, curfile = ...

local _M = {__name = __name}

local package = package
local pconfig = package.config
local cpathes = package.cpath

local searchpath = package.searchpath
local type = type

-- 在旧版 lua 中，loader 可能不会传入 curfile
if not curfile then
  curfile = debug and debug.getinfo(1, 'S').source:match("@?(.+)")
  or searchpath(__name, package.path)
end

-- 模块储存的目录
local prefix = curfile:sub(1, -18)
_M._PREFIX = prefix

local cwd = curfile:gsub('........$', '%%s.lua')

-- 引用当前模块目录的其它脚本
local loadfile = loadfile
local function refer(to, ...)
  local f = loadfile(cwd:format(to))
  return f(_M, ...)
end


-- 获取 lua 版本
local luaver = tonumber(_VERSION:sub(5, -1))
_M.luaver = luaver

-- 提取当前发行版的系统配置
refer "env_info"

local osenv = _M.osenv
local arch = _M.osarch
local libext = _M.libext


local path_sep = pconfig:sub(3, 3)
local name_repl = pconfig:sub(5, 5)

-- 获取第一个可写的 cpath
local function getcapth()
  for p in cpathes:gmatch(("[^%s]+"):format(path_sep)) do
    local tmp = p:gsub(name_repl,
    (".tmp_%d"):format(math.random(1e5)))
    local tmpf = io.open(tmp, 'w')
    if tmpf then
      tmpf:close()
      os.remove(tmp)
      return p
    end
  end error("no accesible cpath.", 2)
end

_M.getcpath = getcapth

local cpath = getcapth()
_M.cpath = cpath

local dir_sep = pconfig:sub(1, 1)
local cp = dir_sep == "\\" and "copy" or "cp"
local concat = table.concat

-- 如果可能的话，更建议手动复制文件
-- installlib 是为那些无法访问安装位置的环境（如 Androlua）准备的
local function installlib(pname)
  pname = pname:gsub('%$o', osenv):gsub('%$a', arch)
  local src = concat{prefix, pname:gsub('%.', dir_sep), libext}
  local dest = cpath:gsub(name_repl, pname:match("[^.]+$"))
  os.execute(concat({cp, src, dest}, ' '))
end

_M.installlib = installlib


local liblist = {
  "packagex.lib.$o.$a.rawtype",
  "packagex.lib.$o.$a.charat"
}

_M.liblist = liblist

-- 安装依赖（手动运行一次即可）
function _M.install()
  for i = 1, #liblist do
    installlib(liblist[i])
  end
end

_M.inited = false

-- 延迟初始化
function _M.init()
  if _M.inited then return end
  refer "packagex" -- 模块主逻辑
  _M.include "packagex"
  _M.inited = true
end

return _M