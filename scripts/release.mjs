#!/usr/bin/env node
// Release helper for the Tide Android app. No dependencies, so it runs the
// same on a laptop and on a GitHub runner.
//
//   node scripts/release.mjs bump <patch|minor|major>   new version + changelog section
//   node scripts/release.mjs check                      the current version has release notes
//   node scripts/release.mjs info                       version, build and tag (GITHUB_OUTPUT aware)
//   node scripts/release.mjs notes [version]            that version's changelog section, as markdown
//   node scripts/release.mjs manifest --url U --sha256 S --size N
//                                                       rewrites public/version.json
//
// The version lives in exactly one place, product/pubspec.yaml. Everything
// else (the tag, the APK name, the website's version number, the in-app
// update check) is derived from it by this script.

import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
// The release workflow publishes from main but describes the commit CI
// tested, so it can point these two at that commit's copies.
const paths = {
  pubspec: process.env.RELEASE_PUBSPEC ?? join(root, "product", "pubspec.yaml"),
  changelog: process.env.RELEASE_CHANGELOG ?? join(root, "CHANGELOG.md"),
  manifest: join(root, "public", "version.json"),
};

const PLACEHOLDER = "Describe what changed.";
const VERSION_LINE = /^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$/m;
const SECTION = /^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?[ \t]*$/gm;

function fail(message) {
  console.error(`release: ${message}`);
  process.exit(1);
}

function readPubspec() {
  const text = readFileSync(paths.pubspec, "utf8");
  const match = text.match(VERSION_LINE);
  if (!match) fail("product/pubspec.yaml has no `version: X.Y.Z+N` line.");
  const [, major, minor, patch, build] = match.map(Number);
  return { text, major, minor, patch, build, version: `${major}.${minor}.${patch}` };
}

/** Every `## [x]` section of the changelog, in file order. */
function readChangelog() {
  const text = readFileSync(paths.changelog, "utf8");
  const heads = [...text.matchAll(SECTION)];
  const sections = heads.map((head, i) => {
    const start = head.index + head[0].length;
    const end = i + 1 < heads.length ? heads[i + 1].index : text.length;
    return {
      name: head[1],
      date: head[2] ?? null,
      index: head.index,
      bodyStart: start,
      bodyEnd: end,
      body: text.slice(start, end).trim(),
    };
  });
  return { text, sections };
}

function bullets(body) {
  return body
    .split(/\r?\n/)
    .map((line) => line.match(/^\s*[-*]\s+(.*\S)\s*$/)?.[1])
    .filter(Boolean);
}

/** The local calendar date, not UTC: a release cut in the evening in India
 * should not be dated the day before. */
function today() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function bump(kind) {
  const pub = readPubspec();
  let { major, minor, patch } = pub;
  if (kind === "major") [major, minor, patch] = [major + 1, 0, 0];
  else if (kind === "minor") [minor, patch] = [minor + 1, 0];
  else if (kind === "patch") patch += 1;
  else fail("bump needs one of: patch, minor, major.");

  const version = `${major}.${minor}.${patch}`;
  const build = pub.build + 1;

  const log = readChangelog();
  if (log.sections.some((s) => s.name === version)) {
    fail(`CHANGELOG.md already has a section for ${version}.`);
  }
  const unreleased = log.sections.find((s) => s.name === "Unreleased");
  if (!unreleased) fail("CHANGELOG.md needs a `## [Unreleased]` section.");

  // Whatever was collected under Unreleased becomes this version's notes.
  const collected = unreleased.body || `### Changed\n\n- ${PLACEHOLDER}`;
  const next =
    log.text.slice(0, unreleased.bodyStart) +
    `\n\n## [${version}] - ${today()}\n\n${collected}\n\n` +
    log.text.slice(unreleased.bodyEnd).replace(/^\s+/, "");

  writeFileSync(paths.changelog, next);
  writeFileSync(
    paths.pubspec,
    pub.text.replace(VERSION_LINE, `version: ${version}+${build}`),
  );

  console.log(`Tide ${pub.version}+${pub.build} -> ${version}+${build}`);
  if (!unreleased.body) {
    console.log(
      `CHANGELOG.md: fill in the notes for ${version} before pushing (the placeholder fails the release check).`,
    );
  }
}

function sectionFor(version) {
  const section = readChangelog().sections.find((s) => s.name === version);
  if (!section) fail(`CHANGELOG.md has no \`## [${version}] - YYYY-MM-DD\` section.`);
  return section;
}

function check() {
  const { version } = readPubspec();
  const section = sectionFor(version);
  const notes = bullets(section.body);
  if (!section.date) fail(`The ${version} section in CHANGELOG.md needs a date.`);
  if (notes.length === 0) fail(`The ${version} section in CHANGELOG.md has no entries.`);
  if (notes.some((n) => n === PLACEHOLDER)) {
    fail(`The ${version} section in CHANGELOG.md still has the placeholder entry.`);
  }
  console.log(`Tide ${version}: ${notes.length} changelog entries.`);
}

function info() {
  const { version, build } = readPubspec();
  const values = { version, build: String(build), tag: `v${version}` };
  const out = process.env.GITHUB_OUTPUT;
  const lines = Object.entries(values).map(([k, v]) => `${k}=${v}`);
  if (out) appendFileSync(out, lines.join("\n") + "\n");
  console.log(lines.join("\n"));
}

function notes(version) {
  const section = sectionFor(version ?? readPubspec().version);
  console.log(section.body);
}

function manifest(args) {
  const flag = (name) => {
    const i = args.indexOf(`--${name}`);
    return i === -1 ? undefined : args[i + 1];
  };
  const url = flag("url") ?? "";
  const sha256 = (flag("sha256") ?? "").toLowerCase();
  const size = Number(flag("size") ?? 0);
  if (url && !url.startsWith("https://")) fail("--url must be https.");
  if (sha256 && !/^[0-9a-f]{64}$/.test(sha256)) fail("--sha256 must be 64 hex characters.");

  const { version, build } = readPubspec();
  const section = sectionFor(version);

  let previous = {};
  try {
    previous = JSON.parse(readFileSync(paths.manifest, "utf8"));
  } catch {
    // First manifest: nothing to carry over.
  }

  const data = {
    version,
    build,
    releasedAt: section.date ?? today(),
    // Raising this forces older installs to update. It is carried over
    // rather than derived, so only an explicit edit ever raises it.
    minSupportedVersion: previous.minSupportedVersion ?? "1.0.0",
    android: { url, sha256, size },
    notes: bullets(section.body),
  };
  writeFileSync(paths.manifest, JSON.stringify(data, null, 2) + "\n");
  console.log(`public/version.json -> ${version}+${build}`);
}

const [command, ...rest] = process.argv.slice(2);
switch (command) {
  case "bump":
    bump(rest[0]);
    break;
  case "check":
    check();
    break;
  case "info":
    info();
    break;
  case "notes":
    notes(rest[0]);
    break;
  case "manifest":
    manifest(rest);
    break;
  default:
    fail("usage: release.mjs <bump|check|info|notes|manifest>");
}
