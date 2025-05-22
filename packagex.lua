local _M = ... or {}
if _M.gsub then _M = {__name = _M} end
-- 预期从 init 接收参数，也可独立运行

local require = require
local _G = _G or require("_G")
_M._G = _G

_M.luaver = _M.luaver or _G.tonumber(_G._VERSION:sub(5, -1))
local outdated = _M.luaver < 5.2
local _ENV = _M
if outdated then setfenv(1, _ENV) end


local _P = _G.package or require("package")
local locate = _P.searchpath
local loaded = _P.loaded
_P.require = require
_M.loaded = loaded -- 同步 loaded

local pcall = _G.pcall
local ok, rawtype = pcall(require, "rawtype")
local type = ok and rawtype or _G.type -- 没有 rawtype 用 type 替代
local setmt = _G.setmetatable
local next = _G.next
local get = _G.rawget

local weak_val = {__mode = 'v'}
local envs = setmt({}, weak_val)
_M.envs = envs -- 收集模块 env

local preloaders = _P.preload

local paths = _P.path
local cpaths = _P.cpath
-- 因为字符串不能同步，所以新符号单独弄了 config
_M.config = '>\n'
-- '>' 用于导入table中的域，如 require "tablex.tablex>cpoy"

local loadfile = _G.loadfile
local loadlib = _P.loadlib


-- 模块 不应该访问用户创建的表
local function read_G(_, k)
  local v = get(_G, k)
  return type(v) ~= "table" and v
  or (v == loaded[k] and v) -- 只能访问已导入的库
end
-- 目的是防止意外的修改
-- 如果确定地需要修改，应该显式使用 _G.table_name

local m_MT = {__index = read_G}
-- setmt(_M, m_MT)  … 感觉很鸡肋，丢了

local ok, charat = pcall(require, "charat")
_G.string.at = ok and charat
or function(self, i) -- 如果 charat 库未正确导入
  return self:sub(i, i) -- 替代方案：使用标准库
end


------- 导入函数原型 -------

-- 预导入
local function import_pre(name, ...)
  local loader = preloaders[name]
  if loader then
    return loader(...) or true
  end
  return nil, ("preload['%s'] not exist."):format(name)
end


-- 导入lua模块
local function import_lua(name, env, ...)
  local path, err = locate(name, paths)
  if not path then
    return path, err
  end

  env = env or setmt({__name = name}, m_MT)
  -- 使用给出的 env (如 _G )，否则分配单独的 env
  local loader = loadfile(path, 'bt', env)
  if loader then
    envs[name] = env
    return (... and loader(...) or loader(name, path)) or true
    -- 复刻原版 require 特性：默认传入 name 和 path
  end

  -- 一般来说，loadfile会自己报错，不会执行到这一条
  -- 我不知道什么时候会报错，所以暂时没有更具体的错误信息
  return nil, ("failed loading '%s'."):format(path)
end


-- 导入动态库
local function import_lib(name, ...)
  local path, err = locate(name, cpaths)
  if not path then
    return path, err
  end

  local entrance = "luaopen_" .. name:gsub('%.', '_')
  local loader = loadlib(path, entrance)
  if loader then
    return loader(...) or true
  end

  -- 如果权限不允许导入动态库的话，可能出现这一条
  return nil, ("failed loading '%s', possibly due to permission denied."):format(path)
end



local searchers = {
  import_pre,
  import_lua,
  import_lib
}
_M.searchers = searchers



-- 遍历搜索器导入模块
local function requirex(name, env, ...)
  local pname = name:match(("^[^%s]+"):format(_M.config:at(1)))
  -- 获取表示路径的部分

  local pkg = loaded[pname]
  local err, i = {}, 0

  while not pkg do
    i = i + 1
    pkg, err[i] = searchers[i](pname, env, ...)
  end

  loaded[pname] = pkg
  or _G.error(_G.table.concat(err, '\n'), 2)

  if pname == name or type(pkg) ~= "table" then return pkg end

  local names = {pname}; i = 1
  local function getField(k) return pkg[k] end

  for field in name:gmatch((">([^%s]+)"):format(_M.config:at(1))) do
    -- 获取表示成员名的部分
    local ok, item = pcall(getField, field)
    -- 访问 table 或 userdata，或其它有元表的类型（如 string 和轻量模式的 userdata)
    if ok then
      pkg = item
      i = i + 1
      names[i] = field
     else _G.error(("package '%s' has no filed '%s'."):
      format(_G.table.concat(names, _M.config:at(1)), field))
    end
  end

  loaded[name] = pkg
  return pkg
end

_M.requirex = requirex



------- 其它风格的导入函数 -------


-- 导入模块内的变量到环境
local function include(name, _env, ...)
  _env = _env or _G -- 默认导入全局环境
  local ns

  if type(name) ~= "table" then
    local pkg = requirex(name, ...)

    ns = envs[name] -- 环境优先
    if ns then
      local k1 = next(ns)
      if not k1 or k1 ~= '__name' or next(ns, k1) then
        -- 如果环境是只含'__name'键的表，不视为有效
        local last = name:match("[^.]+$")
        ns[last] = ns[last] or pkg -- 解决某些即改环境又返回值的模块
       else ns = pkg
      end
     else ns = pkg -- 返回值备用
    end

   else ns = name
  end

  if type(ns) == "table" then -- 处理 table 中的域
    if type(ns.__export) == "table" then
      ns = ns.__export -- 如果指定了导出组，直接采用
      _env = type(ns[1]) == "table" and ns[1] or _env
    end
  
    if type(ns.__exports) == "table" then
      -- 如果指定了多个导出组
      local exports = ns.__exports
      local export
      for i = 1, #exports do
        export = exports[i]
        include(export, type(export[1]) == "table" and export[1] or _env)
      end
      return ns
    end 
  
    for k, v in next, ns do
      if type(k) == "string" -- 不要导入 非字符串
        and k:at(1) ~= '_' -- 不要导入 私有字段
        and nil == get(_env, k) then -- 防止覆盖原有值
        _env[k] = v
      end
    end return ns
   elseif ns and ns ~= true then -- 处理除 table 之外的有效值
    local k = name:match("[^.]+$")
    if nil == get(_env, k) then _env[k] = ns end
    return ns
    -- else: 如果用了预导入器或者c api，
    -- 它们的环境不受模块系统控制，所以可能会什么都没有
  end
end

_M.include = include


-- 从模块中导入指定的对象
local function from_import(this, name)
  local ns = this[1]
  local ntype = type(name)
  if ntype == "table" then -- 导入多个
    local k
    for i = 1, #name do
      k = name[i]
      if k:at(1) ~= '_' and nil == get(_G, k)
        then _G[k] = ns[k] end
    end
   elseif ntype ~= "string" then return
    _G.error(("invalid argument type '%s'."):format(ntype), 2)
   elseif name == '*' then -- 导入全部
    include(ns, _G)
   elseif name:at(1) ~= '_' and nil == get(_G, k) then
    _G[name] = ns[name]
  end
end


-- 示例 from "mod": import "foo"
local function from(name)
  local pkg = requirex(name)

  -- 和 include 里面的一段好像是一样的
  local ns = envs[name]
  if ns then
    local k1 = next(ns)
    if not k1 or k1 ~= '__name' or next(ns, k1) then
      local last = name:match("[^.]+$")
      ns[last] = pkg
     else ns = pkg
    end
   else ns = pkg
  end

  if type(ns) ~= "table" then
    _G.error("the module must have a namespace.", 2)
  end

  return { pkg,
    import = from_import }
end

_M.from = from



------- 《全局命名空间扩展》机制 -------


local extns = {inited = false}
_M.extns = extns

function extns.init()
  if extns.inited then return end

  local _NS = {}
  extns._NS = _NS

  local global_MT = _G.getmetatable(_G) or {}

  -- 原来的扩展空间（如果有）
  local original = global_MT.__index
  local t = type(original)
  _NS[0] = t == "table" and original
  or t == "function" and function(k)
    return original(_G, k)
  end or nil

  -- 各个模块的环境
  _NS[1] = function(k)
    local val
    for _, env in next, envs do
      val = get(env, k)
      if nil ~= val then return val end
    end
  end

  -- 已经导入但没有分配全局变量名的模块
  _NS[2] = loaded

  _NS.n = 2

  -- 注册新的扩展空间
  local function regns(ns)
    local t = type(ns)
    if t == "function" or t == "table" then
      _NS.n = _NS.n + 1
      _NS[_NS.n] = ns
    end
  end

  extns.regns = regns

  function global_MT:__index(k)
    local item
    for i = 0, _NS.n do
      local f = _NS[i]
      local t = type(f)
      if t == "function" then item = f(k)
       elseif t == "table" then item = get(f, k) end
      if nil ~= item then return item end
    end
  end

  setmt(_G, global_MT)
  extns.inited = true
end


-- 定义导出组
__export = {
  rawtype = loaded.rawtype,
  requirex = requirex,
  include = include,
  from = from
}

loaded.packagex = _M
envs.packagex = _ENV


-- 处理独立运行情况
if not _M.init then
  function init()
    if not inited then
      inited = true
      return include "packagex"
    end
  end
end

return _M