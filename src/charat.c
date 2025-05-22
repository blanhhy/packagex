#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// to access chars in a string with index in Lua.
static int char_at(lua_State *L) {
    size_t len;
    const char *str = luaL_checklstring(L, 1, &len);
    lua_Integer idx = luaL_checkinteger(L, 2);

    if (idx < 1 || idx > (lua_Integer)len) {
        lua_pushnil(L);
    } else {
        lua_pushlstring(L, &str[idx-1], 1);
    }
    return 1;
}

int luaopen_charat(lua_State *L) {
    lua_pushcfunction(L, char_at);
    return 1;
}
