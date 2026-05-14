#!/usr/bin/env node
/**
 * Verify the source map(s) Gradle produces for a Hermes Android Release build,
 * then resolve the same frames Faro sent to Grafana.
 *
 * Hermes Android release pipeline (`./gradlew installRelease` / `bundleReleaseJsAndAssets`):
 *
 *   1. Metro produces JS bundle + Metro packager source map (JS bundle bytes -> original sources).
 *      `@grafana/faro-metro-plugin` autodetects this Hermes-precompile pipeline and emits the
 *      packager map in its multi-line shape (no flatten) so step 3 can compose it.
 *   2. `hermesc` compiles the JS bundle to HBC bytecode and emits an HBC source map
 *      (HBC bytes -> JS bundle bytes).
 *   3. `compose-source-maps.js` composes packager.map ∘ hbc.map into the final
 *      `index.android.bundle.map` (HBC bytes -> original sources). This is the **only**
 *      map that resolves frames the device actually emits at runtime, and the one to upload
 *      with `faro-cli metro upload`, for example (from `Mobiles/react-native/` after a release
 *      bundle; default composed path for `release`):
 *
 *        npx faro-cli metro upload \
 *          --map android/app/build/generated/sourcemaps/react/release/index.android.bundle.map \
 *          --endpoint "$FARO_SOURCEMAP_ENDPOINT" \
 *          --app-id "$FARO_SOURCEMAP_APP_ID" \
 *          --stack-id "$FARO_SOURCEMAP_STACK_ID" \
 *          --api-key "$FARO_SOURCEMAP_API_KEY" \
 *          --bundle-id "$FARO_BUNDLE_ID" \
 *          --verbose
 *
 *      Omitted flags fall back to matching `FARO_*` env vars; the autolinked Gradle upload
 *      after `bundleReleaseJsAndAssets` runs the same CLI via `faro-upload-source-map`.
 *
 * Default Gradle paths (RN 0.84.x with `com.facebook.react`):
 *
 *   android/app/build/generated/sourcemaps/react/release/index.android.bundle.map           (composed)
 *   android/app/build/generated/sourcemaps/react/release/index.android.bundle.packager.map  (Metro pre-Hermes)
 *   android/app/build/generated/sourcemaps/react/release/index.android.bundle.hbc.map       (Hermes intermediate)
 *
 * Use this script as the pre-flight check before `faro-cli metro upload` (or the Gradle upload
 * task): the COMPOSED map must report `sources>0` and at least one `[APP ]` frame. Older
 * versions of the Metro plugin flattened the packager map at Metro time, which broke `compose-source-maps.js` and produced
 * an empty composed map (`sources=0`); this script makes that failure visible.
 *
 * Usage (run from `Mobiles/react-native/`):
 *
 *   # Auto-detect Gradle outputs and pull fresh frames from `adb logcat -d`
 *   # (requires ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true in the running app and an
 *   # exception triggered after the latest install — see README "Composed source
 *   # map upload (post-Hermes)").
 *   node scripts/verify-sourcemap.js --android-release --logcat
 *
 *   # Same, but skip --logcat to use the embedded sample frames (NOT recommended
 *   # after a rebuild — bundle layout changes shift byte offsets, so resolved
 *   # files will look wrong even when the map is correct).
 *   node scripts/verify-sourcemap.js --android-release
 *
 *   # Or point at a specific .map file
 *   node scripts/verify-sourcemap.js --map android/app/build/generated/sourcemaps/react/release/index.android.bundle.map
 *
 *   # Override the frames manually (CSV of "line:column=function")
 *   node scripts/verify-sourcemap.js --android-release \
 *     --frames "1:1251414=reportHandledException,1:978494=_performTransitionSideEffects"
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

let SourceMapConsumer;
try {
  ({ SourceMapConsumer } = require('source-map'));
} catch (_e) {
  process.stderr.write(
    'The "source-map" package is required.\n' +
      'Install once:\n' +
      '  npm i -D source-map@^0.7\n' +
      'Or run without installing:\n' +
      '  npx --yes -p source-map@^0.7 node scripts/verify-sourcemap.js --android-release\n',
  );
  process.exit(2);
}

function parseArgs(argv) {
  const out = {
    maps: [],
    frames: null,
    autoAndroid: false,
    autoIos: false,
    logcat: false,
    logcatSerial: null,
    logcatClear: false,
    logcatWaitMs: 0,
    iosLog: false,
    iosLogFile: null,
    iosLogLastMs: 600_000,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--map') out.maps.push(argv[++i]);
    else if (a === '--frames') out.frames = argv[++i];
    else if (a === '--android-release') out.autoAndroid = true;
    else if (a === '--ios-release') out.autoIos = true;
    else if (a === '--logcat') out.logcat = true;
    else if (a === '--logcat-serial') out.logcatSerial = argv[++i];
    else if (a === '--logcat-clear') out.logcatClear = true;
    else if (a === '--logcat-wait') out.logcatWaitMs = parseInt(argv[++i], 10) || 0;
    else if (a === '--ios-log') {
      out.iosLog = true;
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        out.iosLogFile = next;
        i++;
      }
    } else if (a === '--ios-log-last') {
      out.iosLogLastMs = parseInt(argv[++i], 10) || 600_000;
    } else if (a === '-h' || a === '--help') {
      printUsage();
      process.exit(0);
    }
  }
  return out;
}

function printUsage() {
  process.stdout.write(
    'Usage:\n' +
      '  node scripts/verify-sourcemap.js --android-release [--logcat] [--frames "L:C=name,..."]\n' +
      '  node scripts/verify-sourcemap.js --ios-release [--ios-log] [--frames "L:C=name,..."]\n' +
      '  node scripts/verify-sourcemap.js --map <path-to-.map> [--map <path-to-.map>] ...\n' +
      '\n' +
      'Options (Android):\n' +
      '  --android-release      Autodetect Gradle COMPOSED + PACKAGER maps under\n' +
      '                         android/app/build/generated/sourcemaps/react/release/.\n' +
      '  --logcat               Pull the freshest [Faro diagnostics][exception-frames-json] payload\n' +
      '                         from `adb logcat -d` and use it as the frame set.\n' +
      '  --logcat-clear         Run `adb logcat -c` first, then pause for --logcat-wait ms before\n' +
      '                         reading. Use to capture only the next exception you trigger.\n' +
      '  --logcat-wait <ms>     With --logcat-clear, wait this long before reading (default 0).\n' +
      '  --logcat-serial <id>   Pass `-s <id>` to adb (multiple devices/emulators).\n' +
      '\n' +
      'Options (iOS):\n' +
      '  --ios-release          Autodetect the latest composed `main.jsbundle.map` under\n' +
      '                         ~/Library/Developer/Xcode/DerivedData (mtime-sorted).\n' +
      '  --ios-log [<file>]     Read the freshest [Faro diagnostics][exception-frames-json] payload\n' +
      '                         from iOS Simulator logs. Without <file>, runs\n' +
      '                         `xcrun simctl spawn booted log show --info --debug --last 10m\n' +
      "                          --predicate 'eventMessage CONTAINS \"Faro diagnostics\"'`.\n" +
      '                         With <file>, reads that text file instead (e.g. saved from log show).\n' +
      '  --ios-log-last <ms>    With --ios-log (no file), look back this many milliseconds (default 600000).\n' +
      '\n' +
      'Generic:\n' +
      '  --map <path>           One or more explicit .map paths.\n' +
      '  --frames "L:C=fn,..."  Override frames manually (CSV of generated line:column=function).\n',
  );
}

const DEFAULT_FRAMES = [
  { line: 1, column: 1251414, fn: 'reportHandledException' },
  { line: 1, column: 978494, fn: '_performTransitionSideEffects' },
  { line: 1, column: 977919, fn: '_receiveSignal' },
  { line: 1, column: 1265375, fn: 'onResponderRelease' },
  { line: 1, column: 374176, fn: 'executeDispatch' },
  { line: 1, column: 378429, fn: 'executeDispatchesAndReleaseTopLevel' },
  { line: 1, column: 886037, fn: 'anonymous' },
  { line: 1, column: 466352, fn: 'batchedUpdatesImpl' },
  { line: 1, column: 378351, fn: 'batchedUpdates$1' },
  { line: 1, column: 378844, fn: 'dispatchEvent' },
];

function parseFramesFlag(s) {
  return s.split(',').map((entry, i) => {
    const [pos, fn] = entry.split('=');
    const [lineRaw, colRaw] = pos.split(':');
    const line = parseInt(lineRaw, 10);
    const column = parseInt(colRaw, 10);
    if (Number.isNaN(line) || Number.isNaN(column)) {
      throw new Error(`Invalid frame at index ${i}: "${entry}"`);
    }
    return { line, column, fn: fn || '' };
  });
}

/**
 * Pull the most recent `[Faro diagnostics][exception-frames-json]` payload from
 * `adb logcat -d` and return its frames. The bootstrap diagnostics emit the
 * payload in chunked parts when long: `[part i/total] <chunk>`. We reassemble
 * the latest complete chunk group and JSON.parse it.
 */
function readFramesFromLogcat(opts) {
  const { serial = null, clear = false, waitMs = 0 } = opts;
  const adbBase = serial ? ['-s', serial] : [];

  if (clear) {
    try {
      execFileSync('adb', [...adbBase, 'logcat', '-c'], {
        stdio: ['ignore', 'ignore', 'pipe'],
      });
      process.stdout.write('Cleared adb logcat ring buffer.\n');
    } catch (e) {
      throw new Error(`Failed to clear adb logcat: ${e?.message ?? e}`);
    }
    if (waitMs > 0) {
      process.stdout.write(
        `Waiting ${waitMs}ms — trigger the exception in the app now (Debug → Handled exception)…\n`,
      );
      // A bare setTimeout keeps Node's event loop alive until it fires, so this
      // gives us a portable synchronous sleep without `sleep`/Atomics tricks.
      execFileSync(
        process.execPath,
        ['-e', `setTimeout(() => {}, ${waitMs});`],
        { stdio: 'ignore' },
      );
    }
  }

  const args = [...adbBase, 'logcat', '-d'];
  let raw;
  try {
    raw = execFileSync('adb', args, {
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    throw new Error(
      `Failed to run 'adb ${args.join(' ')}'. Is adb on PATH and a device/emulator attached?\n` +
        `Underlying error: ${e?.message ?? e}`,
    );
  }

  const lines = raw.split('\n');
  const TAG = '[Faro diagnostics][exception-frames-json]';
  const FARO_DIAG_TAG = '[Faro diagnostics]';
  const PART_RE = /\[part (\d+)\/(\d+)\] /;
  // adb logcat default threadtime format:
  //   `MM-DD HH:MM:SS.MMM PID TID LEVEL TAG: BODY`
  const LOGCAT_LINE_RE =
    /^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s+(\d+)\s+(\d+)\s+([A-Z])\s+([^:]+?):\s?(.*)$/;

  /**
   * Parse the logcat stream into emissions of `[Faro diagnostics][exception-frames-json]`.
   * Each emission collects the tagged line PLUS any subsequent same-(pid,tid,tag) lines
   * whose body doesn't itself carry a `[Faro diagnostics]` tag. This covers two cases:
   *   1. Single-line payload (preferred — see logChunked in src/bootstrap.ts).
   *   2. Pretty-printed JSON whose `\n`s were split across logcat lines by the React
   *      Native console bridge (legacy/buggy emission shape from older app builds).
   */
  const emissions = [];
  let cur = null;
  const closeCur = () => {
    if (cur) {
      emissions.push(cur);
      cur = null;
    }
  };
  for (let i = 0; i < lines.length; i++) {
    const m = LOGCAT_LINE_RE.exec(lines[i]);
    if (!m) {
      closeCur();
      continue;
    }
    const pid = m[2];
    const tid = m[3];
    const logcatTag = m[5];
    const body = m[6];
    const tagIdx = body.indexOf(TAG);
    if (tagIdx >= 0) {
      closeCur();
      cur = {
        pid,
        tid,
        logcatTag,
        firstBody: body.slice(tagIdx + TAG.length).trimStart(),
        continuationBodies: [],
      };
      continue;
    }
    if (
      cur &&
      cur.pid === pid &&
      cur.tid === tid &&
      cur.logcatTag === logcatTag &&
      !body.includes(FARO_DIAG_TAG)
    ) {
      cur.continuationBodies.push(body);
    } else {
      closeCur();
    }
  }
  closeCur();

  if (emissions.length === 0) {
    // Help the user diagnose. Look for the broader [Faro diagnostics] tag — if
    // *that* exists, only the JSON chunk is missing (older app build, perhaps).
    const broaderHits = lines.filter((l) => l.includes('[Faro diagnostics]')).length;
    const adbCmd = ['adb', ...adbBase, 'logcat', '-d'].join(' ');
    let hint =
      `No '${TAG}' lines in adb logcat output (broader '[Faro diagnostics]' lines: ${broaderHits}).\n\n` +
      'Most likely causes (in order):\n' +
      '  1. The release APK on the device was not rebuilt + reinstalled with the new\n' +
      '     @grafana/faro-metro-plugin. `:app:createBundleReleaseJsAndAssets` only writes\n' +
      '     the JS bundle to your laptop — it does NOT install the APK. Run:\n' +
      '       ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true \\\n' +
      '         ( cd android && ./gradlew installRelease )\n' +
      '     and confirm `adb logcat | rg \'\\[Faro diagnostics\\]\\[init\\]\'` shows the new\n' +
      '     bundleId after the next app start.\n' +
      '  2. You did not trigger an exception since the latest install. Open the app and\n' +
      '     tap Debug → Handled exception, then re-run with --logcat.\n' +
      '  3. The Android logcat ring buffer rotated past those lines. Use:\n' +
      '       node scripts/verify-sourcemap.js --android-release --logcat \\\n' +
      '         --logcat-clear --logcat-wait 15000\n' +
      '     and trigger the exception within 15s of seeing "Cleared adb logcat ring buffer".\n' +
      '\n' +
      `Diagnostic command:\n  ${adbCmd} | rg '\\[Faro diagnostics\\]'\n`;
    if (broaderHits > 0) {
      hint +=
        '\nNote: broader [Faro diagnostics] lines were found, so the running app DOES emit\n' +
        'diagnostics — only the chunked frames-json line is missing. That usually means the\n' +
        'app was last installed before the bootstrap.ts logChunked change shipped. Reinstall.\n';
    }
    throw new Error(hint);
  }

  // Reduce each emission to its inline content. For chunked emissions (firstBody
  // starts with `[part i/N] …`), keep the part header so we can stitch siblings
  // below. For non-chunked emissions, fold any newline-split continuation lines
  // back into the body — JSON whitespace is permissive so plain concatenation
  // with '\n' is enough to reconstruct a parseable payload.
  const reduced = emissions.map((em) => {
    const m = PART_RE.exec(em.firstBody);
    if (m) {
      return {
        kind: 'chunk',
        part: parseInt(m[1], 10),
        total: parseInt(m[2], 10),
        body:
          em.firstBody.replace(PART_RE, '') +
          (em.continuationBodies.length > 0
            ? '\n' + em.continuationBodies.join('\n')
            : ''),
      };
    }
    return {
      kind: 'full',
      body:
        em.firstBody +
        (em.continuationBodies.length > 0
          ? '\n' + em.continuationBodies.join('\n')
          : ''),
    };
  });

  // Group consecutive chunks that share a `[part i/N]` total into one payload.
  // Standalone (non-chunked) emissions are their own group.
  const groups = [];
  let chunkAcc = null;
  const flushChunkAcc = () => {
    if (chunkAcc) {
      groups.push(chunkAcc);
      chunkAcc = null;
    }
  };
  for (const r of reduced) {
    if (r.kind === 'full') {
      flushChunkAcc();
      groups.push({ kind: 'single', body: r.body });
      continue;
    }
    if (r.part === 1 || chunkAcc == null || chunkAcc.total !== r.total) {
      flushChunkAcc();
      chunkAcc = {
        kind: 'multi',
        total: r.total,
        parts: new Array(r.total).fill(''),
        have: 0,
      };
    }
    if (chunkAcc.parts[r.part - 1] === '') {
      chunkAcc.parts[r.part - 1] = r.body;
      chunkAcc.have += 1;
    }
    if (chunkAcc.have === chunkAcc.total) {
      flushChunkAcc();
    }
  }
  flushChunkAcc();

  // Pick the latest complete group.
  let payload = null;
  for (let i = groups.length - 1; i >= 0; i--) {
    const g = groups[i];
    if (g.kind === 'single') {
      payload = g.body;
      break;
    }
    if (g.kind === 'multi' && g.have === g.total) {
      payload = g.parts.join('');
      break;
    }
  }
  if (!payload) {
    throw new Error(
      `Found ${emissions.length} '${TAG}' emission(s) in logcat but none formed a complete payload. ` +
        `Trigger the exception again after the device buffer has stabilised, then retry.`,
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(payload);
  } catch (e) {
    throw new Error(`Could not parse '${TAG}' payload as JSON: ${e?.message ?? e}`);
  }
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error(`'${TAG}' payload is not a non-empty array.`);
  }
  return parsed.map((f) => ({
    line: typeof f.lineno === 'number' ? f.lineno : 1,
    column: typeof f.colno === 'number' ? f.colno : 0,
    fn: typeof f.function === 'string' ? f.function : '',
  }));
}

/**
 * Pull the most recent `[Faro diagnostics][exception-frames-json]` payload from the
 * iOS Simulator log. Unlike `adb logcat` (PID/TID-grouped threadtime), `xcrun simctl
 * log show` keeps each `console.info` emission on its own line, so we only need the
 * chunked `[part i/N]` reassembly used by `bootstrap.ts` `logChunked`.
 */
function readFramesFromIosLog(opts) {
  const { file = null, lastMs = 600_000 } = opts;

  let raw;
  if (file) {
    try {
      raw = fs.readFileSync(file, 'utf8');
    } catch (e) {
      throw new Error(
        `Failed to read --ios-log file '${file}': ${e?.message ?? e}`,
      );
    }
  } else {
    const lastSec = Math.max(1, Math.floor(lastMs / 1000));
    const args = [
      'simctl',
      'spawn',
      'booted',
      'log',
      'show',
      '--info',
      '--debug',
      '--last',
      `${lastSec}s`,
      '--predicate',
      'eventMessage CONTAINS "Faro diagnostics"',
    ];
    try {
      raw = execFileSync('xcrun', args, {
        encoding: 'utf8',
        maxBuffer: 64 * 1024 * 1024,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (e) {
      throw new Error(
        `Failed to run 'xcrun ${args.join(' ')}'.\n` +
          `Is Xcode command-line tools installed and a Simulator booted?\n` +
          `Tip: \`xcrun simctl list devices booted\`.\n` +
          `Underlying error: ${e?.message ?? e}`,
      );
    }
  }

  const TAG = '[Faro diagnostics][exception-frames-json]';
  const PART_RE = /\[part (\d+)\/(\d+)\] /;
  const lines = raw.split('\n');

  const emissions = [];
  for (const line of lines) {
    const idx = line.indexOf(TAG);
    if (idx < 0) continue;
    const body = line.slice(idx + TAG.length).trimStart();
    const m = PART_RE.exec(body);
    if (m) {
      emissions.push({
        kind: 'chunk',
        part: parseInt(m[1], 10),
        total: parseInt(m[2], 10),
        body: body.replace(PART_RE, ''),
      });
    } else {
      emissions.push({ kind: 'full', body });
    }
  }

  if (emissions.length === 0) {
    const broaderHits = lines.filter((l) => l.includes('[Faro diagnostics]')).length;
    const sourceDesc = file ? `'${file}'` : `xcrun simctl log show (last ${Math.floor(lastMs / 1000)}s)`;
    let hint =
      `No '${TAG}' lines found in ${sourceDesc} (broader '[Faro diagnostics]' lines: ${broaderHits}).\n\n` +
      'Most likely causes (in order):\n' +
      '  1. The Release app was not rebuilt + reinstalled with @grafana/faro-react-native including\n' +
      '     the bootstrap diagnostics. Run with ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true in the same\n' +
      '     shell as `yarn ios --mode Release`, then trigger Debug → Handled exception.\n' +
      '  2. No exception triggered since the latest install. Open the app and tap\n' +
      '     Debug → Handled exception, then re-run with --ios-log.\n' +
      '  3. The log window is too narrow. Increase it: --ios-log-last 1800000 (30 min).\n' +
      '\n' +
      `Diagnostic command:\n  xcrun simctl spawn booted log show --info --debug --last 30m --predicate 'eventMessage CONTAINS "Faro diagnostics"'\n`;
    if (broaderHits > 0) {
      hint +=
        '\nNote: broader [Faro diagnostics] lines were found, so the app DOES emit diagnostics — only the\n' +
        'chunked frames-json line is missing. Reinstall the Release build with the latest SDK.\n';
    }
    throw new Error(hint);
  }

  // Group consecutive chunks that share a `[part i/N]` total into one payload.
  const groups = [];
  let chunkAcc = null;
  const flush = () => {
    if (chunkAcc) {
      groups.push(chunkAcc);
      chunkAcc = null;
    }
  };
  for (const r of emissions) {
    if (r.kind === 'full') {
      flush();
      groups.push({ kind: 'single', body: r.body });
      continue;
    }
    if (r.part === 1 || chunkAcc == null || chunkAcc.total !== r.total) {
      flush();
      chunkAcc = {
        kind: 'multi',
        total: r.total,
        parts: new Array(r.total).fill(''),
        have: 0,
      };
    }
    if (chunkAcc.parts[r.part - 1] === '') {
      chunkAcc.parts[r.part - 1] = r.body;
      chunkAcc.have += 1;
    }
    if (chunkAcc.have === chunkAcc.total) {
      flush();
    }
  }
  flush();

  // Pick the latest complete payload.
  let payload = null;
  for (let i = groups.length - 1; i >= 0; i--) {
    const g = groups[i];
    if (g.kind === 'single') {
      payload = g.body;
      break;
    }
    if (g.kind === 'multi' && g.have === g.total) {
      payload = g.parts.join('');
      break;
    }
  }
  if (!payload) {
    throw new Error(
      `Found ${emissions.length} '${TAG}' emission(s) in iOS log but none formed a complete payload. ` +
        `Trigger the exception again and re-run.`,
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(payload);
  } catch (e) {
    throw new Error(`Could not parse '${TAG}' payload as JSON: ${e?.message ?? e}`);
  }
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error(`'${TAG}' payload is not a non-empty array.`);
  }
  return parsed.map((f) => ({
    line: typeof f.lineno === 'number' ? f.lineno : 1,
    column: typeof f.colno === 'number' ? f.colno : 0,
    fn: typeof f.function === 'string' ? f.function : '',
  }));
}

function classify(src) {
  if (!src) return 'NONE';
  if (src.includes('/node_modules/') || src.startsWith('node_modules/')) return 'DEP ';
  if (src.includes('/src/') || src.startsWith('src/')) return 'APP ';
  return 'OTH ';
}

async function checkOneMap(label, mapPath, frames) {
  const raw = fs.readFileSync(mapPath, 'utf8');
  const map = JSON.parse(raw);

  const flat =
    typeof map.mappings === 'string' ? !map.mappings.includes(';') : null;

  process.stdout.write(
    `\n=== ${label} ===\n` +
      `  path: ${mapPath}\n` +
      `  version=${map.version} file=${map.file ?? '(missing)'} sources=${
        Array.isArray(map.sources) ? map.sources.length : '?'
      } flatHermesShape(no ";")=${String(flat)}\n`,
  );

  const consumer = await new SourceMapConsumer(map);
  let app = 0;
  let dep = 0;
  let none = 0;
  let oth = 0;
  try {
    for (const f of frames) {
      const pos = consumer.originalPositionFor({
        line: f.line,
        column: f.column,
      });
      const src = pos.source ?? null;
      const tag = classify(src);
      if (tag === 'APP ') app++;
      else if (tag === 'DEP ') dep++;
      else if (tag === 'NONE') none++;
      else oth++;

      process.stdout.write(
        `  [${tag}] (${f.line}:${f.column}) client=${f.fn}\n` +
          `         -> ${src ?? '(unresolved)'}:${pos.line ?? '?'}:${pos.column ?? '?'} name=${pos.name ?? ''}\n`,
      );
    }
  } finally {
    consumer.destroy?.();
  }
  process.stdout.write(
    `  summary: APP=${app}  DEP=${dep}  OTH=${oth}  NONE=${none}\n`,
  );
  return { label, mapPath, app, dep, none, oth, flat };
}

function autoAndroidPaths() {
  const base = path.resolve(
    'android/app/build/generated/sourcemaps/react/release',
  );
  return [
    {
      label: 'COMPOSED (Hermes-final — upload this via faro-upload-source-map)',
      file: path.join(base, 'index.android.bundle.map'),
    },
    {
      label: 'PACKAGER (Metro pre-Hermes intermediate — do NOT upload)',
      file: path.join(base, 'index.android.bundle.packager.map'),
    },
  ];
}

/**
 * Walk a directory looking for `main.jsbundle.map` files (any depth), returning absolute paths.
 * Skips inaccessible/hidden subtrees silently so a partial DerivedData layout doesn't abort scan.
 */
function findIosMaps(dir, out, maxDepth) {
  if (maxDepth <= 0) return;
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (_e) {
    return;
  }
  for (const e of entries) {
    if (e.name.startsWith('.')) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      findIosMaps(p, out, maxDepth - 1);
    } else if (e.isFile() && e.name === 'main.jsbundle.map') {
      out.push(p);
    }
  }
}

function autoIosPaths() {
  const home = process.env.HOME || '';
  if (!home) return [];
  const derivedRoot = path.join(home, 'Library/Developer/Xcode/DerivedData');
  if (!fs.existsSync(derivedRoot)) return [];
  const all = [];
  let projectRoots;
  try {
    projectRoots = fs.readdirSync(derivedRoot, { withFileTypes: true });
  } catch (_e) {
    return [];
  }
  for (const e of projectRoots) {
    if (!e.isDirectory() || e.name.startsWith('.')) continue;
    const intermediates = path.join(derivedRoot, e.name, 'Build', 'Intermediates.noindex');
    if (!fs.existsSync(intermediates)) continue;
    findIosMaps(intermediates, all, 10);
  }
  if (all.length === 0) return [];
  // Sort by mtime desc and keep the top 1 — the freshest composed map for the just-built target.
  const withStats = all
    .map((file) => ({ file, mtimeMs: fs.statSync(file).mtimeMs }))
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
  return [
    {
      label: 'COMPOSED iOS (Hermes-final — uploaded by Xcode Release Run Script)',
      file: withStats[0].file,
    },
  ];
}

async function main() {
  const args = parseArgs(process.argv);
  let frames;
  let framesSource;
  if (args.frames) {
    frames = parseFramesFlag(args.frames);
    framesSource = '--frames flag';
  } else if (args.logcat) {
    frames = readFramesFromLogcat({
      serial: args.logcatSerial,
      clear: args.logcatClear,
      waitMs: args.logcatWaitMs,
    });
    framesSource = `adb logcat (${frames.length} frame${frames.length === 1 ? '' : 's'})`;
  } else if (args.iosLog) {
    frames = readFramesFromIosLog({
      file: args.iosLogFile,
      lastMs: args.iosLogLastMs,
    });
    framesSource = args.iosLogFile
      ? `ios log file '${args.iosLogFile}' (${frames.length} frame${frames.length === 1 ? '' : 's'})`
      : `xcrun simctl log show (${frames.length} frame${frames.length === 1 ? '' : 's'})`;
  } else {
    frames = DEFAULT_FRAMES;
    framesSource =
      'embedded sample frames (stale after a rebuild — pass --logcat or --ios-log for fresh ones)';
  }
  process.stdout.write(`Frames source: ${framesSource}\n`);

  let targets = [];
  if (args.autoAndroid) {
    for (const t of autoAndroidPaths()) {
      if (fs.existsSync(t.file)) {
        targets.push(t);
      } else {
        process.stdout.write(`(skip, missing) ${t.label}: ${t.file}\n`);
      }
    }
    if (targets.length === 0) {
      process.stderr.write(
        '\nNo Gradle source maps found under android/app/build/generated/sourcemaps/react/release/.\n' +
          'Build first:\n' +
          '  ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true ( cd android && ./gradlew bundleReleaseJsAndAssets )\n' +
          'Or for a full install:\n' +
          '  ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true ( cd android && ./gradlew installRelease )\n',
      );
      process.exit(2);
    }
  } else if (args.autoIos) {
    const candidates = autoIosPaths();
    for (const t of candidates) {
      if (fs.existsSync(t.file)) {
        targets.push(t);
      } else {
        process.stdout.write(`(skip, missing) ${t.label}: ${t.file}\n`);
      }
    }
    if (targets.length === 0) {
      process.stderr.write(
        '\nNo iOS composed map found under ~/Library/Developer/Xcode/DerivedData/**/main.jsbundle.map.\n' +
          'Build a Release first:\n' +
          '  ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true yarn ios -- --mode Release --verbose\n' +
          'Or pass an explicit --map <path-to>/main.jsbundle.map.\n',
      );
      process.exit(2);
    }
  } else if (args.maps.length > 0) {
    targets = args.maps.map((m) => ({ label: path.basename(m), file: path.resolve(m) }));
  } else {
    printUsage();
    process.exit(2);
  }

  const results = [];
  for (const t of targets) {
    if (!fs.existsSync(t.file)) {
      process.stderr.write(`Missing: ${t.file}\n`);
      continue;
    }
    results.push(await checkOneMap(t.label, t.file, frames));
  }

  const composed =
    results.find((r) => r.label.startsWith('COMPOSED')) ??
    (results.length === 1 ? results[0] : undefined);
  if (!composed) {
    return;
  }

  process.stdout.write('\n=== Verdict ===\n');
  const totalResolved = composed.app + composed.dep + composed.oth;
  const composedHasSources = totalResolved > 0;

  if (composed.app > 0) {
    process.stdout.write(
      '  PASS: COMPOSED map resolves device frames into the app source tree.\n' +
        `        APP=${composed.app}  DEP=${composed.dep}  OTH=${composed.oth}  NONE=${composed.none}\n` +
        '        DEP frames going to node_modules/react-native/* are expected — those\n' +
        '        are React Native\'s own touch/event/reconciler callbacks. Only the topmost\n' +
        '        user-code frame is from your app.\n' +
        '\n' +
        '  Next steps:\n' +
        '    1. Upload the composed map to Faro with `faro-cli metro upload` (or rely on the\n' +
        '       autolinked Gradle task when env vars are set at build time), e.g.:\n' +
        '         npx faro-cli metro upload \\\n' +
        '           --map android/app/build/generated/sourcemaps/react/release/index.android.bundle.map \\\n' +
        '           --endpoint "$FARO_SOURCEMAP_ENDPOINT" \\\n' +
        '           --app-id "$FARO_SOURCEMAP_APP_ID" \\\n' +
        '           --stack-id "$FARO_SOURCEMAP_STACK_ID" \\\n' +
        '           --api-key "$FARO_SOURCEMAP_API_KEY" \\\n' +
        '           --bundle-id "$FARO_BUNDLE_ID" \\\n' +
        '           --verbose\n' +
        '    2. Re-install the release APK and trigger the exception (Debug → Handled exception).\n' +
        '    3. Confirm in Frontend Observability that the top frame points at your src/ file.\n',
    );
  } else if (!composedHasSources) {
    process.stdout.write(
      '  FAIL: COMPOSED map exists but has no source mappings. compose-source-maps.js could\n' +
        '  not match the packager map against the HBC map. Most likely cause: an older\n' +
        '  @grafana/faro-metro-plugin flattened the packager map before Hermes ran.\n' +
        '  Upgrade @grafana/faro-metro-plugin to a version that autodetects Hermes precompile\n' +
        '  (it ships with bin/faro-upload-source-map.js), reinstall (yarn install), then rerun:\n' +
        '    ( cd android && ./gradlew :app:bundleReleaseJsAndAssets --rerun-tasks )\n',
    );
  } else {
    process.stdout.write(
      '  WARN: COMPOSED map has source mappings, all frames resolve outside src/.\n' +
        `        APP=${composed.app}  DEP=${composed.dep}  OTH=${composed.oth}  NONE=${composed.none}\n` +
        '        Likely causes:\n' +
        '          - The frames came from a different build than this map. Re-run with --logcat\n' +
        '            after triggering the exception against the *current* installed build.\n' +
        '          - bundleId mismatch between the device payload and this build.\n',
    );
  }
}

main().catch((e) => {
  process.stderr.write(`Error: ${e?.stack || e}\n`);
  process.exit(1);
});
