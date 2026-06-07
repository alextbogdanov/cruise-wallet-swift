#!/usr/bin/env node
//
// import-assets.mjs — wire generated PNGs into Assets.xcassets (Phase 3)
//
// For every PNG in Cruzero/Resources/Generated/ that the manifest knows about,
// create a single-scale universal imageset under
// Assets.xcassets/<generatedGroup>/<name>.imageset/ with a Contents.json, so
// Swift can reference it as Image("<name>"). The special "app-icon-source"
// asset is also copied into AppIcon.appiconset as the 1024 icon.
//
// This step is idempotent and free — re-run it any time without touching fal.
//
// Usage:
//   node import-assets.mjs            # import everything present in Generated/
//   node import-assets.mjs --clean    # remove imagesets whose PNG is gone too
//
import { readFile, writeFile, mkdir, copyFile, readdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

// generate-assets.mjs guarantees real PNG output (it transcodes WebP/JPEG from
// fal), and actool only accepts known extensions — so the catalog is PNG-only.
function findSource(outDir, name) {
  const p = path.join(outDir, `${name}.png`);
  return existsSync(p) ? p : null;
}

function imagesetContents(filename) {
  // No "scale" key ⇒ Xcode treats it as a Single-Scale universal image,
  // used at its native pixel resolution. Perfect for high-res generated PNGs
  // without needing @2x / @3x variants.
  return {
    images: [{ filename, idiom: "universal" }],
    info: { author: "xcode", version: 1 },
  };
}

// Expand manifest assets to the concrete imageset names (mirrors generator).
function expectedNames(manifest) {
  const names = [];
  for (const asset of manifest.assets) {
    const count = asset.count && asset.count > 1 ? asset.count : 1;
    if (count > 1) for (let i = 1; i <= count; i++) names.push({ name: `${asset.name}-${i}`, asset });
    else names.push({ name: asset.name, asset });
  }
  return names;
}

async function writeJSON(p, obj) {
  await writeFile(p, JSON.stringify(obj, null, 2) + "\n");
}

async function importImageset(name, src, catalogGroupDir) {
  const setDir = path.join(catalogGroupDir, `${name}.imageset`);
  // Rebuild the imageset so a prior import leaves no stale file behind.
  await rm(setDir, { recursive: true, force: true });
  await mkdir(setDir, { recursive: true });
  const filename = `${name}.png`;
  await copyFile(src, path.join(setDir, filename));
  await writeJSON(path.join(setDir, "Contents.json"), imagesetContents(filename));
}

async function importAppIcon(src, catalogRoot) {
  const iconSet = path.join(catalogRoot, "AppIcon.appiconset");
  if (!existsSync(iconSet)) return false;
  // Drop any previously-imported icon (possibly a different extension).
  for (const e of ["png", "webp", "jpg", "jpeg"]) {
    await rm(path.join(iconSet, `app-icon-1024.${e}`), { force: true });
  }
  const filename = "app-icon-1024.png";
  await copyFile(src, path.join(iconSet, filename));
  await writeJSON(path.join(iconSet, "Contents.json"), {
    images: [{ idiom: "universal", platform: "ios", size: "1024x1024", filename }],
    info: { author: "xcode", version: 1 },
  });
  return true;
}

async function main() {
  const clean = process.argv.includes("--clean");
  const manifest = JSON.parse(await readFile(path.join(__dirname, "asset-manifest.json"), "utf8"));
  const outDir = path.join(ROOT, manifest.outputDir);
  const catalogRoot = path.join(ROOT, manifest.assetCatalog);
  const groupDir = path.join(catalogRoot, manifest.generatedGroup || "Generated");

  if (!existsSync(outDir)) {
    console.log(`Nothing to import — ${path.relative(ROOT, outDir)} does not exist yet.`);
    console.log(`Run \`node tools/generate-assets.mjs\` first (needs FAL_KEY).`);
    return;
  }

  await mkdir(groupDir, { recursive: true });
  // A folder Contents.json keeps the group from becoming a namespace.
  await writeJSON(path.join(groupDir, "Contents.json"), {
    info: { author: "xcode", version: 1 },
    properties: { "provides-namespace": false },
  });

  const expected = expectedNames(manifest);
  let imported = 0, missing = 0, icons = 0;

  for (const { name, asset } of expected) {
    const src = findSource(outDir, name);
    if (!src) {
      missing++;
      continue;
    }
    if (asset.appIcon) {
      if (await importAppIcon(src, catalogRoot)) icons++;
    }
    await importImageset(name, src, groupDir);
    imported++;
    console.log(`  ✓ ${name}.imageset`);
  }

  if (clean) {
    const present = new Set(expected.map((e) => e.name));
    for (const entry of await readdir(groupDir, { withFileTypes: true })) {
      if (!entry.isDirectory() || !entry.name.endsWith(".imageset")) continue;
      const base = entry.name.replace(/\.imageset$/, "");
      const stillHasSource = findSource(outDir, base) !== null;
      if (!present.has(base) || !stillHasSource) {
        await rm(path.join(groupDir, entry.name), { recursive: true, force: true });
        console.log(`  ✗ removed stale ${entry.name}`);
      }
    }
  }

  console.log(`\nImported ${imported} imageset(s)` + (icons ? `, ${icons} app icon` : "") + `.`);
  if (missing > 0) {
    console.log(`${missing} manifest asset(s) not yet generated — run generate-assets.mjs to fill them in.`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
