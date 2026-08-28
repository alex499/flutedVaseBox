import * as THREE from "three";
import { OrbitControls } from "./vendor/OrbitControls.js";
import { STLLoader } from "./vendor/STLLoader.js";
import { serialise, parse } from "./config.js";

// Purely a visual reference grid — flutedVaseBox has no unit system of its own.
const GRID_UNIT = 10;

/* ---------------------------------------------------------------- parameters */

// Everything the model is asked for. Ranges here must match the // [..] annotations
// in flutedvasebox.scad; the ids in index.html are the OpenSCAD variable names.
function readParams() {
  const params = {};
  for (const el of document.querySelectorAll("[data-param]")) {
    const kind = el.dataset.param;
    params[el.id] =
      kind === "bool" ? el.checked :
      kind === "int" ? parseInt(el.value, 10) :
      kind === "float" ? parseFloat(el.value) :
      el.value;
  }
  return params;
}

/* ------------------------------------------------- the link in the address bar */

// Read off the controls themselves, so index.html stays the only place the parameters
// and their ranges are written down.
function schema() {
  const s = {};
  for (const el of document.querySelectorAll("[data-param]")) {
    const kind = el.dataset.param;
    s[el.id] = kind === "bool"
      ? { kind, fallback: el.defaultChecked }
      : { kind, min: Number(el.min), max: Number(el.max), fallback: Number(el.defaultValue) };
  }
  return s;
}

// the inverse of readParams
function applyParams(params) {
  for (const el of document.querySelectorAll("[data-param]")) {
    if (!(el.id in params)) continue;
    if (el.dataset.param === "bool") el.checked = params[el.id];
    else el.value = params[el.id];
  }
}

// replaceState, not pushState: a slider drag must not fill the back button
function rememberInUrl() {
  history.replaceState(null, "", "#" + serialise(readParams()));
}

function fileName({ width, depth, height }) {
  return `flutedvasebox-${width}x${depth}x${height}.stl`;
}

/* ------------------------------------------------------------------- the scene */

const viewer = document.getElementById("viewer");
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(35, 1, 1, 4000);
camera.up.set(0, 0, 1);
camera.position.set(160, -190, 130);

// transparent, so the stage keeps its CSS background and follows the light/dark theme
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setClearAlpha(0);
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
viewer.appendChild(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.12;

scene.add(new THREE.HemisphereLight(0xffffff, 0x707078, 2.1));
const key = new THREE.DirectionalLight(0xffffff, 2.0);
key.position.set(0.6, -1, 1.3);
scene.add(key);
const fill = new THREE.DirectionalLight(0xffffff, 0.7);
fill.position.set(-0.9, 0.5, 0.4);
scene.add(fill);

const material = new THREE.MeshStandardMaterial({
  color: 0x3fae82, roughness: 0.55, metalness: 0.04, flatShading: false,
});

let mesh = null;
let grid = null;
let framedRadius = 0;

function resize() {
  const { clientWidth: w, clientHeight: h } = viewer;
  if (!w || !h) return;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
new ResizeObserver(resize).observe(viewer);
resize();

(function loop() {
  requestAnimationFrame(loop);
  controls.update();
  renderer.render(scene, camera);
})();

function showGeometry(geometry) {
  geometry.computeBoundingBox();
  const box = geometry.boundingBox;
  const centre = box.getCenter(new THREE.Vector3());
  // centre it in X and Y, and stand it on z = 0 so the grid reads as the table
  geometry.translate(-centre.x, -centre.y, -box.min.z);
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();

  if (mesh) {
    scene.remove(mesh);
    mesh.geometry.dispose();
  }
  mesh = new THREE.Mesh(geometry, material);
  scene.add(mesh);

  const size = box.getSize(new THREE.Vector3());
  layGrid(Math.max(size.x, size.y));

  // keep the angle the user orbited to; only re-fit when the model changed size
  const radius = geometry.boundingSphere.radius;
  if (Math.abs(radius - framedRadius) > 0.15 * framedRadius) {
    const target = new THREE.Vector3(0, 0, size.z / 2);
    const direction = camera.position.clone().sub(controls.target).normalize();
    const distance = radius / Math.sin(THREE.MathUtils.degToRad(camera.fov / 2)) * 1.2;
    controls.target.copy(target);
    camera.position.copy(target).addScaledVector(direction, distance);
    framedRadius = radius;
  }
}

// one square per grid unit, so the footprint is readable at a glance
const dark = matchMedia("(prefers-color-scheme: dark)");
let gridSpan = 0;

function layGrid(span) {
  gridSpan = span;
  const units = Math.max(2, Math.ceil(span / GRID_UNIT) + 4);
  if (grid) {
    if (grid.userData.units === units && grid.userData.dark === dark.matches) return;
    scene.remove(grid);
    grid.dispose();
  }
  const [line, minor] = dark.matches ? [0x44444e, 0x303038] : [0xc8c8cc, 0xe2e2e6];
  grid = new THREE.GridHelper(units * GRID_UNIT, units, line, minor);
  grid.rotation.x = Math.PI / 2;
  grid.position.z = -0.05;
  grid.userData.units = units;
  grid.userData.dark = dark.matches;
  scene.add(grid);
}

dark.addEventListener("change", () => { if (grid) layGrid(gridSpan); });

/* ------------------------------------------------------------------ the worker */

const worker = new Worker(new URL("./render-worker.js", import.meta.url), { type: "module" });
const loader = new STLLoader();

const statusText = document.getElementById("status-text");
const status = document.getElementById("status");
const dlStl = document.getElementById("dl-stl");
let sequence = 0;
let latestPreview = 0;
const pendingDownloads = new Map();

function setStatus(text, state = "busy") {
  statusText.textContent = text;
  status.dataset.state = state;
}

worker.onmessage = ({ data }) => {
  if (data.kind === "download") {
    const job = pendingDownloads.get(data.id);
    pendingDownloads.delete(data.id);
    dlStl.disabled = false;
    if (!data.ok) return setStatus(data.error, "error");
    saveFile(data.stl, job.name);
    setStatus(`Saved ${job.name}`, "idle");
    return;
  }

  if (data.id !== latestPreview) return;   // a newer preview has already been asked for
  if (!data.ok) return setStatus(data.error, "error");

  showGeometry(loader.parse(data.stl.buffer));
  setStatus(`Rendered in ${(data.ms / 1000).toFixed(2)} s`, "idle");
  dlStl.disabled = false;
};

worker.onerror = (e) => setStatus(`Worker failed: ${e.message}`, "error");

function saveFile(bytes, name) {
  const url = URL.createObjectURL(new Blob([bytes], { type: "model/stl" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

function requestPreview() {
  const params = readParams();
  const id = ++sequence;
  latestPreview = id;
  setStatus("Rendering…");
  worker.postMessage({ id, kind: "preview", params });
}

function requestDownload() {
  const params = readParams();
  const id = ++sequence;
  const name = fileName(params);
  pendingDownloads.set(id, { name });
  dlStl.disabled = true;
  setStatus(`Rendering ${name}…`);
  worker.postMessage({ id, kind: "download", params });
}

/* --------------------------------------------------------------------- the UI */

const reset = document.getElementById("reset");

// an empty fragment is the defaults, so this is the link the untouched page carries
const defaultLink = serialise(parse("", schema()));

function syncUI() {
  for (const el of document.querySelectorAll("output[for]")) {
    const input = document.getElementById(el.htmlFor);
    el.textContent = input.value;
  }
  reset.toggleAttribute("data-dirty", serialise(readParams()) !== defaultLink);
}

let debounce = 0;
function onChange() {
  syncUI();
  clearTimeout(debounce);
  // the address is rewritten once the change settles, not once per slider tick
  debounce = setTimeout(() => { rememberInUrl(); requestPreview(); }, 150);
}

document.getElementById("panel").addEventListener("input", onChange);
reset.addEventListener("click", () => { applyParams(parse("", schema())); onChange(); });
dlStl.addEventListener("click", requestDownload);

// someone pasting a different link into the address bar; replaceState does not fire this
addEventListener("hashchange", () => {
  const incoming = location.hash.replace(/^#/, "");
  if (incoming === serialise(readParams())) return;
  applyParams(parse(incoming, schema()));
  onChange();
});

if (location.hash.length > 1) applyParams(parse(location.hash, schema()));
syncUI();
rememberInUrl();   // normalise the address, filling in whatever the link left out
setStatus("Loading OpenSCAD…");
requestPreview();
