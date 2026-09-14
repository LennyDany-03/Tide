import { readFileSync } from "node:fs";
import { join } from "node:path";

export type ChangeGroup = { title: string; items: string[] };

export type ChangelogEntry = {
  version: string;
  date: string | null;
  groups: ChangeGroup[];
};

/**
 * Reads CHANGELOG.md at build time.
 *
 * Only the shape scripts/release.mjs writes is understood: `## [version] -
 * date` headings, `### Group` subheadings and `- item` bullets. Anything else
 * in a section is ignored rather than rendered half-formatted.
 */
export function readChangelog(): ChangelogEntry[] {
  const text = readFileSync(join(process.cwd(), "CHANGELOG.md"), "utf8");
  const entries: ChangelogEntry[] = [];
  let entry: ChangelogEntry | null = null;
  let group: ChangeGroup | null = null;

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    const heading = line.match(/^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?$/);
    if (heading) {
      entry = { version: heading[1], date: heading[2] ?? null, groups: [] };
      group = null;
      entries.push(entry);
      continue;
    }
    if (!entry) continue;

    const sub = line.match(/^### (.+)$/);
    if (sub) {
      group = { title: sub[1], items: [] };
      entry.groups.push(group);
      continue;
    }

    const item = line.match(/^\s*[-*]\s+(.*\S)$/);
    if (item) {
      if (!group) {
        group = { title: "Changes", items: [] };
        entry.groups.push(group);
      }
      group.items.push(item[1]);
    }
  }

  return entries.filter(
    (e) => e.groups.some((g) => g.items.length > 0) && e.version !== "Unreleased",
  );
}

export type InlinePart =
  | { kind: "text"; value: string }
  | { kind: "code"; value: string }
  | { kind: "strong"; value: string }
  | { kind: "link"; value: string; href: string };

/** Splits a changelog line into `code`, **bold** and [link](url) runs. */
export function parseInline(line: string): InlinePart[] {
  const parts: InlinePart[] = [];
  const pattern = /`([^`]+)`|\*\*([^*]+)\*\*|\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  let last = 0;
  for (const match of line.matchAll(pattern)) {
    if (match.index > last) {
      parts.push({ kind: "text", value: line.slice(last, match.index) });
    }
    if (match[1]) parts.push({ kind: "code", value: match[1] });
    else if (match[2]) parts.push({ kind: "strong", value: match[2] });
    else parts.push({ kind: "link", value: match[3], href: match[4] });
    last = match.index + match[0].length;
  }
  if (last < line.length) parts.push({ kind: "text", value: line.slice(last) });
  return parts;
}
