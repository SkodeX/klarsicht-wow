// Runs the Klarsicht addon in a Lua VM (fengari) against wowmock.lua.
// Usage: node run.js            -> all flavor/locale combinations
// Needs: npm install (fengari, luaparse) and methods.lua (see methods.js).
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const here = __dirname;
const addonDir = process.env.KLARSICHT_DIR || path.join(here, '..', 'Klarsicht');
const toc = fs.readFileSync(path.join(addonDir, 'Klarsicht.toc'), 'utf8');
const files = toc.split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith('#'));

// 1) Lua 5.1 syntax (the game's dialect)
for (const f of files) {
  luaparse.parse(fs.readFileSync(path.join(addonDir, f), 'utf8'), { luaVersion: '5.1' });
}

function run(scenario, flavor, locale) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const exec = (src, name) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + name)) !== lua.LUA_OK ||
        lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
  };
  const read = f => fs.readFileSync(f, 'utf8');
  exec('METHODS = (function() ' + read(path.join(here, 'methods.lua')) + ' end)()', 'methods.lua');
  exec(read(path.join(here, 'wowmock.lua')), 'wowmock.lua');
  exec(`MOCK.locale = "${locale}"; MOCK.scenario = "${scenario}"` + (flavor === 'forever' ? '; MOCK.UseForever()' : ''), 'setup');
  // Load addon files in TOC order with the (addonName, namespace) varargs.
  exec('NS = {}; ADDON_FILES = {}', 'setup');
  for (const f of files) {
    const src = read(path.join(addonDir, f));
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@Klarsicht/' + f)) !== lua.LUA_OK) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
    lua.lua_pushstring(L, to_luastring('Klarsicht'));
    lua.lua_getglobal(L, to_luastring('NS'));
    if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  exec(`local ok, err = xpcall(function() ${read(path.join(here, scenario + '.lua'))} end, debug.traceback)
        if not ok then error(err, 0) end`, scenario + '.lua');
}

let failed = 0;
for (const scenario of ['mage', 'priest', 'layout', 'auras']) {
  for (const flavor of ['classic', 'forever']) {
    for (const locale of ['deDE', 'enUS']) {
      try { run(scenario, flavor, locale); }
      catch (e) { failed++; console.log(`FAIL ${scenario} ${flavor}/${locale}:\n${e.message}\n`); }
    }
  }
}
process.exit(failed ? 1 : 0);
