// Checks that the page renders the same solid the openscad CLI does, by driving the real
// render-worker.js from node with self/fetch stubbed. Run `node build.js` first.
//
//   node verify.js          parity on a spread of sizes, then a sweep for errors
//   node verify.js sweep    the sweep only
import { execFile } from "node:child_process";
import { readFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { serialise, parse } from "./config.js";

const run = promisify(execFile);
const web = dirname(fileURLToPath(import.meta.url));
const site = join(web, "_site");

/* the worker expects a browser: a self to post to, and a fetch for the .scad */

const replies = new Map();
globalThis.self = {
  location: { href: `file://${site}/` },
  postMessage: (msg) => replies.get(msg.id)?.(msg),
};
globalThis.fetch = async (url) => {
  const path = join(site, String(url).replace(/^file:\/\//, "").slice(site.length));
  return { ok: true, status: 200, text: () => readFile(path, "utf8") };
};

await import(join(site, "render-worker.js"));

let nextId = 0;
function render(params, kind = "download") {
  const id = ++nextId;
  return new Promise((resolve) => {
    replies.set(id, (msg) => { replies.delete(id); resolve(msg); });
    self.onmessage({ data: { id, kind, params } });
  });
}

/* measuring the result */

// the page asks for binstl; the CLI writes ascii unless told otherwise, so read either
function triangles(bytes) {
  const head = Buffer.from(bytes.buffer, bytes.byteOffset, Math.min(512, bytes.byteLength));
  return head.toString("latin1").startsWith("solid") && head.includes("facet")
    ? asciiTriangles(Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength).toString("latin1"))
    : binaryTriangles(bytes);
}

function binaryTriangles(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const n = view.getUint32(80, true);
  const out = [];
  for (let i = 0; i < n; i++) {
    const o = 84 + i * 50 + 12;
    const v = [];
    for (let k = 0; k < 9; k++) v.push(view.getFloat32(o + k * 4, true));
    out.push([v.slice(0, 3), v.slice(3, 6), v.slice(6, 9)]);
  }
  return out;
}

function asciiTriangles(text) {
  const out = [];
  let tri = [];
  for (const m of text.matchAll(/^\s*vertex\s+(\S+)\s+(\S+)\s+(\S+)/gm)) {
    tri.push([Number(m[1]), Number(m[2]), Number(m[3])]);
    if (tri.length === 3) { out.push(tri); tri = []; }
  }
  return out;
}

function measure(bytes) {
  const tris = triangles(bytes);
  let volume = 0;
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const [a, b, c] of tris) {
    volume += (a[0] * (b[1] * c[2] - b[2] * c[1])
             - a[1] * (b[0] * c[2] - b[2] * c[0])
             + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6;
    for (const v of [a, b, c]) for (let i = 0; i < 3; i++) {
      if (v[i] < min[i]) min[i] = v[i];
      if (v[i] > max[i]) max[i] = v[i];
    }
  }
  return { tris: tris.length, volume, size: max.map((m, i) => m - min[i]) };
}

const flags = (p) => Object.entries(p).flatMap(([k, v]) =>
  ["-D", `${k}=${typeof v === "string" ? JSON.stringify(v) : v}`]);

async function cli(params, dir) {
  const out = join(dir, "cli.stl");
  await run("openscad", ["-o", out, ...flags(params), join(web, "..", "flutedvasebox.scad")]);
  return measure(new Uint8Array(await readFile(out)));
}

/* the two checks */

const parityCases = [
  ["default 100x100x50",     { width: 100, depth: 100, height: 50 }],
  ["square, bigger",         { width: 200, depth: 200, height: 80 }],
  ["square, smaller",        { width: 60,  depth: 60,  height: 30 }],
  ["rectangular",            { width: 150, depth: 70,  height: 60 }],
  ["tall and narrow",        { width: 40,  depth: 40,  height: 180 }],
  ["min corner (30x30)",     { width: 30,  depth: 30,  height: 15 }],
  ["max corner (250x250)",   { width: 250, depth: 250, height: 200 }],
];

async function parity() {
  const dir = await mkdtemp(join(tmpdir(), "fvb-"));
  let bad = 0;
  console.log("geometry parity — wasm (as the page runs it) vs the openscad CLI\n");
  for (const [name, params] of parityCases) {
    const msg = await render(params);
    if (!msg.ok) { console.log(`FAIL ${name}: ${msg.error}`); bad++; continue; }
    const w = measure(msg.stl);
    const c = await cli(params, dir);
    // both files store float32, so compare relatively: 1e-5 is far below any real
    // difference in the solid and far above the rounding in the coordinates
    const dv = Math.abs(w.volume - c.volume) / c.volume;
    const ds = Math.max(...w.size.map((s, i) => Math.abs(s - c.size[i])));
    const ok = dv < 1e-5 && ds < 1e-3;
    if (!ok) bad++;
    console.log(
      `${ok ? "ok  " : "FAIL"} ${name.padEnd(22)} ` +
      `vol ${w.volume.toFixed(3).padStart(12)} vs ${c.volume.toFixed(3).padStart(12)} ` +
      `(Δ ${dv.toExponential(1)} rel)  size ${w.size.map((s) => s.toFixed(2)).join(" × ")}`
    );
  }
  await rm(dir, { recursive: true, force: true });
  return bad;
}

async function sweep() {
  console.log("\nsweep — width × depth × height across the slider range, expecting a clean render\n");
  let n = 0, bad = 0;
  for (const width of [30, 100, 175, 250])
    for (const depth of [30, 100, 175, 250])
      for (const height of [15, 50, 125, 200]) {
        const msg = await render({ width, depth, height });
        n++;
        const noise = (msg.log ?? []).filter((l) => /WARNING|ERROR/.test(l));
        if (!msg.ok || noise.length) {
          bad++;
          console.log(`FAIL width=${width} depth=${depth} height=${height}` +
                      `\n     ${msg.error ?? noise.join("\n     ")}`);
        }
      }
  console.log(`${bad ? `${bad} of ${n} failed` : `all ${n} combinations rendered clean`}`);
  return bad;
}

/* the URL fragment: it must round trip, and it must never throw */

// stands in for what schema() reads off the controls in index.html
const testSchema = {
  width:  { kind: "int", min: 30, max: 250, fallback: 100 },
  depth:  { kind: "int", min: 30, max: 250, fallback: 100 },
  height: { kind: "int", min: 15, max: 200, fallback: 50 },
};

function config() {
  console.log("\nURL fragment — round trip, then degradation\n");
  let bad = 0;

  const trips = [
    ["defaults",  { width: 100, depth: 100, height: 50 }],
    ["resized",   { width: 180, depth: 65, height: 90 }],
  ];
  for (const [name, params] of trips) {
    const back = parse(serialise(params), testSchema);
    const same = Object.keys(params).every((k) => back[k] === params[k])
              && Object.keys(back).length === Object.keys(params).length;
    if (!same) {
      bad++;
      console.log(`FAIL round trip ${name}\n     out ${serialise(params)}\n     back ${serialise(back)}`);
    } else {
      console.log(`ok   round trip ${name.padEnd(18)} ${serialise(params).length} chars`);
    }
  }

  // a fragment written against an older model, or by hand, or by a mangled paste
  const junk = [
    ["renamed key dropped",   "rows=2&width=120",       (p) => p.width === 120 && !("rows" in p)],
    ["above range clamped",   "width=999",              (p) => p.width === 250],
    ["below range clamped",   "height=-5",              (p) => p.height === 15],
    ["not a number",          "depth=abc",              (p) => p.depth === 100],
    ["empty fragment",        "",                       (p) => p.width === 100],
    ["broken escape",         "%%%&width=120",          (p) => p.width === 120],
    ["no equals sign",        "width&depth=90",         (p) => p.depth === 90 && p.width === 100],
    ["leading hash",          "#height=80",             (p) => p.height === 80],
    ["undefined",             undefined,                (p) => p.width === 100],
  ];
  for (const [name, text, ok] of junk) {
    let result;
    try {
      result = parse(text, testSchema);
    } catch (e) {
      bad++;
      console.log(`FAIL ${name}: threw ${e.message}`);
      continue;
    }
    const passed = ok(result) && Object.keys(result).length === Object.keys(testSchema).length;
    if (!passed) bad++;
    console.log(`${passed ? "ok  " : "FAIL"} degrades: ${name}`);
  }

  console.log(bad ? `${bad} fragment check(s) failed` : "fragment round trips and never throws");
  return bad;
}

const only = process.argv[2];
let bad = config();
if (only !== "sweep") bad += await parity();
bad += await sweep();
process.exit(bad ? 1 : 0);
