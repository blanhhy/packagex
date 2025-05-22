#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static int rawtype(lua_State *L) {
    luaL_checkany(L, 1);
    int type = lua_type(L, 1);
    const char* type_name = lua_typename(L, type);
    lua_pushstring(L, type_name);
    return 1;
}

int luaopen_rawtype(lua_State *L) {
    lua_pushcfunction(L, rawtype);
    return 1;
}
