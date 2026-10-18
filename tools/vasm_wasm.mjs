// vasm (m68k, Motorola syntax) through the npm WebAssembly build, for Linux
// hosts without a native vasm (cloud sessions). Same arguments as vasmm68k_mot.
// Set VASM_WASM to the unpacked romdev-toolchain-vasm package directory
// (npm pack romdev-toolchain-vasm; tar xzf ...). The repository is loaded
// into the assembler's memory file system; INCLUDE/INCBIN names that differ
// from the real file only in case are aliased (the sources are not changed).
// Usage: node tools/vasm_wasm.mjs -devpac -nocase -m68020 -Fhunkexe -o build/AmiMSX AmiMSX_Main_v3.1.asm
import fs from "node:fs";
import path from "node:path";

const pkg = process.env.VASM_WASM || path.join(path.dirname(new URL(import.meta.url).pathname), "vasm-wasm", "package");
const createVasm = (await import(path.join(pkg, "wasm", "vasm68k.js"))).default;
const root = process.cwd();
const args = process.argv.slice(2);
const outIdx = args.indexOf("-o");
const outFile = outIdx >= 0 ? args[outIdx + 1] : null;

function walk(dir, list) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === ".git" || e.name === "build" || e.name === "node_modules" || e.name === "vasm-wasm") continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, list); else if (e.isFile()) list.push(path.relative(root, p));
  }
}
const files = [];
walk(root, files);
const lower = new Map(files.map(f => [f.toLowerCase(), f]));
// names referenced by INCLUDE/INCBIN in the sources
const refs = new Set();
for (const f of files) {
  if (!/\.(asm|s|i)$/i.test(f)) continue;
  const src = fs.readFileSync(f, "latin1");
  for (const m of src.matchAll(/^[^;\n]*\b(?:INCLUDE|INCBIN)\s+"([^"]+)"/gim)) refs.add(m[1]);
}

let stdout = "", stderr = "";
const mod = await createVasm({
  noInitialRun: true,
  print: s => { stdout += s + "\n"; },
  printErr: s => { stderr += s + "\n"; },
});
const FS = mod.FS;
function put(name, data) {
  const dir = path.posix.dirname(name);
  if (dir !== ".") FS.mkdirTree(dir);
  FS.writeFile(name, data);
}
for (const f of files) put(f.split(path.sep).join("/"), fs.readFileSync(f));
for (const r of refs) {
  const real = lower.get(r.toLowerCase());
  if (real && real !== r) put(r, fs.readFileSync(real));
}
if (outFile) FS.mkdirTree(path.posix.dirname(outFile));
let rc = 0;
try { rc = mod.callMain(args); } catch (e) { if (typeof e === "number") rc = e; else if (e && e.status !== undefined) rc = e.status; else throw e; }
process.stdout.write(stdout); process.stderr.write(stderr);
if (outFile && rc === 0) {
  try { fs.mkdirSync(path.dirname(outFile), { recursive: true }); fs.writeFileSync(outFile, FS.readFile(outFile)); } catch (e) { console.error("no output: " + e.message); rc = 1; }
}
process.exit(rc);
