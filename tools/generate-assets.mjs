#!/usr/bin/env node
//
// generate-assets.mjs — Cruzero fal.ai asset generator (Phase 3)
//
// Reads tools/asset-manifest.json and generates every asset via the fal.ai
// queue REST API, downloading the PNGs into Cruzero/Resources/Generated/.
// Import them into Assets.xcassets afterwards with `node import-assets.mjs`.
//
// Generation is BLOCKED until a FAL_KEY is provided (per MOCKUP.md). Set it in
// tools/.env (copy from .env.example) or export FAL_KEY=... in your shell.
// Until then the app keeps building against the placeholder fallbacks baked
// into Avatar / PhotoTile / PillChip and the procedural TextureBackground.
//
// Usage:
//   node generate-assets.mjs                 # generate everything missing
//   node generate-assets.mjs --force         # re-generate even if PNG exists
//   node generate-assets.mjs --only ship-1   # one asset by name
//   node generate-assets.mjs --category port # one category
//   node generate-assets.mjs --dry-run       # print the resolved jobs only
//   node generate-assets.mjs --concurrency 6
//
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { execFile } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const FAL_QUEUE = "https://queue.fal.run";

// ── tiny .env loader (no dependency) ────────────────────────────────────────
async function loadDotEnv() {
  const envPath = path.join(__dirname, ".env");
  if (!existsSync(envPath)) return;
  const txt = await readFile(envPath, "utf8");
  for (const raw of txt.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const m = line.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/i);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim().replace(/^["']|["']$/g, "");
    if (!process.env[key]) process.env[key] = val;
  }
}

function parseArgs(argv) {
  const args = { only: null, category: null, force: false, dryRun: false, concurrency: 4 };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--force") args.force = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--only") args.only = argv[++i];
    else if (a === "--category") args.category = argv[++i];
    else if (a === "--concurrency") args.concurrency = Math.max(1, parseInt(argv[++i], 10) || 4);
  }
  return args;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Build the per-image job list. An asset with `count > 1` expands into
// `<name>-1 … <name>-n` so each lands in its own imageset.
function expandJobs(manifest) {
  const jobs = [];
  for (const asset of manifest.assets) {
    const count = asset.count && asset.count > 1 ? asset.count : 1;
    for (let i = 1; i <= count; i++) {
      const name = count > 1 ? `${asset.name}-${i}` : asset.name;
      jobs.push({ ...asset, name, index: i, count });
    }
  }
  return jobs;
}

// Compose the final prompt and the fal input payload for a job.
function buildInput(job, manifest) {
  // Cruiser photos get the "person" realism suffix; other photos get the
  // generic scene suffix; illustrations get the illustration suffix.
  const suffixKey = job.styleKey || (job.category === "cruiser" ? "person" : job.type);
  const suffix = manifest.styleSuffix[suffixKey] ?? manifest.styleSuffix[job.type] ?? "";
  const prompt = `${job.prompt} ${suffix}`.trim();
  const model = manifest.models[job.type];
  const input = { prompt, num_images: 1, output_format: "png" };

  // image_size accepts a fal enum string or a { width, height } object.
  if (job.size) input.image_size = job.size;

  if (job.type === "illustration") {
    // recraft-v3 style (flat editorial illustration look).
    input.style = manifest.recraftStyle || "digital_illustration";
  } else {
    // flux-pro/v1.1 realism knobs.
    input.safety_tolerance = "2";
  }
  return { model, input };
}

async function submit(model, input, key) {
  const res = await fetch(`${FAL_QUEUE}/${model}`, {
    method: "POST",
    headers: { Authorization: `Key ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`submit ${model} → ${res.status} ${res.statusText} ${body.slice(0, 300)}`);
  }
  return res.json(); // { request_id, status_url, response_url, cancel_url }
}

async function poll(statusUrl, key, { timeoutMs = 180000, intervalMs = 2500 } = {}) {
  const started = Date.now();
  // The plain Date import is unavailable in some sandboxes; Date.now() is fine here (Node).
  while (Date.now() - started < timeoutMs) {
    const res = await fetch(statusUrl, { headers: { Authorization: `Key ${key}` } });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`status → ${res.status} ${body.slice(0, 200)}`);
    }
    const s = await res.json();
    if (s.status === "COMPLETED") return;
    if (s.status === "FAILED" || s.status === "CANCELLED" || s.status === "ERROR") {
      throw new Error(`request ${s.status}: ${JSON.stringify(s).slice(0, 300)}`);
    }
    await sleep(intervalMs);
  }
  throw new Error("timed out waiting for completion");
}

async function fetchResult(responseUrl, key) {
  const res = await fetch(responseUrl, { headers: { Authorization: `Key ${key}` } });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`result → ${res.status} ${body.slice(0, 200)}`);
  }
  return res.json(); // { images: [{ url, ... }], seed }
}

// Sniff the real format — recraft-v3 returns WebP regardless of output_format.
// actool only accepts known extensions, so anything that isn't already PNG is
// transcoded to a real PNG with `sips` (macOS) before it reaches the catalog.
function extFromBuffer(buf) {
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return "png";
  if (buf.toString("ascii", 0, 4) === "RIFF" && buf.toString("ascii", 8, 12) === "WEBP") return "webp";
  if (buf[0] === 0xff && buf[1] === 0xd8) return "jpg";
  return "png";
}

function sips(args) {
  return new Promise((resolve, reject) => {
    execFile("sips", args, (err, stdout, stderr) => {
      if (err) reject(new Error(`sips failed: ${stderr || err.message}`));
      else resolve(stdout);
    });
  });
}

async function generateOne(job, manifest, key, outDir, force) {
  const dest = path.join(outDir, `${job.name}.png`);
  if (!force && existsSync(dest)) {
    return { name: job.name, status: "skipped", bytes: 0 };
  }
  const { model, input } = buildInput(job, manifest);
  const { request_id, status_url, response_url } = await submit(model, input, key);
  await poll(status_url, key);
  const result = await fetchResult(response_url, key);
  const image = result.images?.[0];
  if (!image?.url) throw new Error(`no image in result (request ${request_id})`);

  const res = await fetch(image.url);
  if (!res.ok) throw new Error(`download → ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  const ext = extFromBuffer(buf);

  let bytes;
  if (ext === "png") {
    await writeFile(dest, buf);
    bytes = buf.length;
  } else {
    // Transcode to a real PNG so extension and content both agree.
    const tmp = path.join(outDir, `.tmp-${job.name}.${ext}`);
    await writeFile(tmp, buf);
    await sips(["-s", "format", "png", tmp, "--out", dest]);
    await rm(tmp, { force: true });
    bytes = (await readFile(dest)).length;
  }
  return { name: job.name, status: "generated", bytes, seed: result.seed, model, request_id };
}

// Simple bounded-concurrency runner.
async function runPool(items, limit, worker) {
  const results = [];
  let cursor = 0;
  const lanes = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (cursor < items.length) {
      const i = cursor++;
      results[i] = await worker(items[i], i);
    }
  });
  await Promise.all(lanes);
  return results;
}

async function main() {
  await loadDotEnv();
  const args = parseArgs(process.argv);

  const manifestPath = path.join(__dirname, "asset-manifest.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  const outDir = path.join(ROOT, manifest.outputDir);
  await mkdir(outDir, { recursive: true });

  let jobs = expandJobs(manifest);
  if (args.category) jobs = jobs.filter((j) => j.category === args.category);
  if (args.only) jobs = jobs.filter((j) => j.name === args.only || j.name.startsWith(`${args.only}-`));

  if (jobs.length === 0) {
    console.error(`No assets match those filters. Known names/categories live in ${path.relative(ROOT, manifestPath)}.`);
    process.exit(1);
  }

  if (args.dryRun) {
    console.log(`Dry run — ${jobs.length} job(s):\n`);
    for (const j of jobs) {
      const { model, input } = buildInput(j, manifest);
      console.log(`• ${j.name}  [${j.category}/${j.type}]  ${model}  size=${JSON.stringify(input.image_size)}`);
      console.log(`    ${input.prompt}\n`);
    }
    return;
  }

  const key = process.env.FAL_KEY;
  if (!key) {
    console.log("─".repeat(72));
    console.log("⛔  FAL_KEY not set — generation is blocked (this is expected per MOCKUP.md).");
    console.log("");
    console.log("    The app still builds: Avatar / PhotoTile / PillChip and the");
    console.log("    procedural TextureBackground render labelled placeholders until");
    console.log("    real assets land in Cruzero/Resources/Generated/.");
    console.log("");
    console.log("    To generate, paste your key:");
    console.log("      cp tools/.env.example tools/.env   # then edit FAL_KEY=...");
    console.log("      node tools/generate-assets.mjs");
    console.log("      node tools/import-assets.mjs");
    console.log("");
    console.log(`    Inspect prompts without a key:  node tools/generate-assets.mjs --dry-run`);
    console.log(`    Manifest defines ${expandJobs(manifest).length} assets across ` +
      `${new Set(manifest.assets.map((a) => a.category)).size} categories.`);
    console.log("─".repeat(72));
    process.exit(0); // non-fatal: pipeline is "ready", just waiting on the key.
  }

  console.log(`Generating ${jobs.length} asset(s) with concurrency ${args.concurrency}…\n`);
  const lock = {};
  let ok = 0, skip = 0, fail = 0;

  await runPool(jobs, args.concurrency, async (job) => {
    try {
      const r = await generateOne(job, manifest, key, outDir, args.force);
      if (r.status === "skipped") {
        skip++;
        console.log(`  ↷ ${job.name} (exists — use --force to regenerate)`);
      } else {
        ok++;
        lock[job.name] = { seed: r.seed, model: r.model, request_id: r.request_id };
        console.log(`  ✓ ${job.name}  (${(r.bytes / 1024).toFixed(0)} KB, seed ${r.seed ?? "?"})`);
      }
      return r;
    } catch (e) {
      fail++;
      console.error(`  ✗ ${job.name}: ${e.message}`);
      return { name: job.name, status: "failed", error: e.message };
    }
  });

  // Record seeds/models so a regen can reproduce the same look.
  const lockPath = path.join(outDir, ".manifest-lock.json");
  let prevLock = {};
  if (existsSync(lockPath)) {
    prevLock = JSON.parse(await readFile(lockPath, "utf8").catch(() => "{}"));
  }
  await writeFile(lockPath, JSON.stringify({ ...prevLock, ...lock }, null, 2));

  console.log(`\nDone — ${ok} generated, ${skip} skipped, ${fail} failed.`);
  console.log(`Next: node tools/import-assets.mjs`);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
