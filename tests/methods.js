// Collect widget method names documented in every flavor (intersection).
const fs = require('fs'), path = require('path');
const ui = process.argv[2], flavors = process.argv.slice(3);
const sets = flavors.map(fl => {
  const dir = path.join(ui, fl, 'Interface/AddOns/Blizzard_APIDocumentationGenerated');
  const names = new Set();
  for (const f of fs.readdirSync(dir).filter(f => /^(Simple|FrameAPI)/.test(f))) {
    const src = fs.readFileSync(path.join(dir, f), 'utf8');
    for (const m of src.matchAll(/Name = "(\w+)",\s*\n\s*Type = "Function"/g)) names.add(m[1]);
  }
  return names;
});
const common = [...sets[0]].filter(n => sets.every(s => s.has(n))).sort();
const onlyFirst = [...sets[0]].filter(n => !sets.every(s => s.has(n)));
fs.writeFileSync(path.join(__dirname, 'methods.lua'), 'return {\n' + common.map(n => `  ${n} = true,`).join('\n') + '\n}\n');
console.log(flavors.join('+'), 'common methods:', common.length, '| only in some flavor:', onlyFirst.length);
