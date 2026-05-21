#!/usr/bin/env node
// Render the shared Arbigent project YAML for a given app/platform.
//
// Reads the scenario template + the shared recovery-hints block, substitutes
// the app-specific placeholders, indents the recovery block to match each
// placeholder's YAML block-scalar context, and writes the result to stdout.
//
// Usage:
//   render-template.js <template_file> <recovery_hints_file> <android_pkg> <ios_bundle_id>
//
// Pure Node stdlib (no npm deps). Kept at this level (not inside
// report-generator/) because the runner uses it independently of the
// report tool.

const fs = require('node:fs');

const [, , templatePath, recoveryPath, androidPkg, iosBundle] = process.argv;

if (!templatePath || !recoveryPath || androidPkg === undefined || iosBundle === undefined) {
  console.error(
    'usage: render-template.js <template_file> <recovery_hints_file> ' +
      '<android_pkg> <ios_bundle_id>',
  );
  process.exit(2);
}

let content = fs.readFileSync(templatePath, 'utf8');
const recovery = fs.readFileSync(recoveryPath, 'utf8').replace(/\n+$/, '');

content = content.replaceAll('__ANDROID_PACKAGE__', androidPkg);
content = content.replaceAll('__IOS_BUNDLE_ID__', iosBundle);

content = content.replace(
  /^([ \t]*)__RECOVERY_BLOCK__[ \t]*$/gm,
  (_match, indent) =>
    recovery
      .split('\n')
      .map((line) => (line ? indent + line : line))
      .join('\n'),
);

process.stdout.write(content);
