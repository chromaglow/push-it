// Adds or removes the push-it hook in a Claude Code settings.json, keeping everything else.
//
// Runs under either runtime, so macOS needs nothing installed:
//   osascript -l JavaScript merge-settings.js <settings.json> add|remove [command]
//   node                   merge-settings.js <settings.json> add|remove [command]
//
// Only push-it's own hook commands are touched: the fallback install
// (.../push-it/app/hooks/push-it.sh) and the pre-1.0 kit (.../push-it/push-hook.{ps1,sh,js}).
// Other hooks, including others in the same group, are kept. Mirrors scripts/lib.ps1.

const OURS = /[\\/]push-it[\\/](app[\\/]hooks[\\/]push-it\.sh|push-hook\.(ps1|sh|js))/;

function merge(settings, mode, command) {
  const s = settings && typeof settings === 'object' && !Array.isArray(settings) ? settings : {};
  const hooks = s.hooks && typeof s.hooks === 'object' ? s.hooks : {};
  const groups = [];
  for (const group of Array.isArray(hooks.UserPromptSubmit) ? hooks.UserPromptSubmit : []) {
    if (!group || !Array.isArray(group.hooks)) { groups.push(group); continue; }
    const kept = group.hooks.filter((h) => !(h && typeof h.command === 'string' && OURS.test(h.command)));
    if (kept.length) groups.push(kept.length === group.hooks.length ? group : Object.assign({}, group, { hooks: kept }));
  }
  if (mode === 'add') groups.push({ hooks: [{ type: 'command', command, timeout: 10 }] });
  if (groups.length) hooks.UserPromptSubmit = groups; else delete hooks.UserPromptSubmit;
  if (Object.keys(hooks).length) s.hooks = hooks; else delete s.hooks;
  return s;
}

function parse(text, path) {
  const t = (text || '').replace(/^﻿/, '');
  if (!t.trim()) return {};
  try { return JSON.parse(t); }
  catch (e) { throw new Error(path + " isn't valid JSON, so it was left unchanged. Fix it (or restore a .bak copy) and rerun."); }
}

function check(mode, command) {
  if (mode !== 'add' && mode !== 'remove') throw new Error('mode must be "add" or "remove"');
  if (mode === 'add' && !command) throw new Error('"add" needs a command');
}

// osascript (JXA) entry point
// eslint-disable-next-line no-unused-vars
function run(argv) {
  ObjC.import('Foundation');
  const [path, mode, command] = argv;
  check(mode, command);
  const fm = $.NSFileManager.defaultManager;
  const text = fm.fileExistsAtPath(path)
    ? $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js : '';
  const out = JSON.stringify(merge(parse(text, path), mode, command), null, 2) + '\n';
  $(out).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
  return 'ok';
}

// node entry point
if (typeof require === 'function' && typeof module !== 'undefined' && require.main === module) {
  const fs = require('fs');
  const [path, mode, command] = process.argv.slice(2);
  try {
    check(mode, command);
    const text = fs.existsSync(path) ? fs.readFileSync(path, 'utf8') : '';
    fs.writeFileSync(path, JSON.stringify(merge(parse(text, path), mode, command), null, 2) + '\n');
  } catch (e) {
    console.error('  X  ' + e.message);
    process.exit(1);
  }
}
