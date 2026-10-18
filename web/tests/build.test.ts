import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { CONTACT, GET_APP } from "../src/lib/site";

const dist = join(import.meta.dir, "..", "dist");
const pages = ["index.html", "privacy/index.html", "support/index.html"];

function html(page: string): string {
  return readFileSync(join(dist, page), "utf8");
}

/** Width and height from a PNG's IHDR chunk (bytes 16-23, big-endian). */
function pngSize(path: string): [number, number] {
  const bytes = readFileSync(path);
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

describe("built site", () => {
  test("every page has an og image that exists at 1200x630", () => {
    for (const page of pages) {
      const match = html(page).match(/<meta property="og:image" content="([^"]+)"/);
      expect(match, `${page} has no og:image`).not.toBeNull();
      const file = join(dist, new URL(match![1]).pathname);
      expect(existsSync(file), `${file} missing`).toBe(true);
      expect(statSync(file).size).toBeGreaterThan(0);
      expect(pngSize(file)).toEqual([1200, 630]);
    }
  });

  test("landing page links to the app", () => {
    expect(GET_APP.href.startsWith("https://")).toBe(true);
    expect(html("index.html")).toContain(`href="${GET_APP.href}"`);
    expect(html("index.html")).toContain(GET_APP.label);
  });

  test("privacy page names the contact", () => {
    expect(html("privacy/index.html")).toContain(CONTACT);
  });

  test("privacy page is honest about what TestFlight shares", () => {
    const page = html("privacy/index.html");
    expect(page).toContain("TestFlight");
    expect(page).not.toContain("None of it reaches me");
  });

  test("copy promises only the 36 characters the app teaches", () => {
    for (const page of ["index.html", "support/index.html"]) {
      expect(html(page)).not.toMatch(/prosign|punctuation/i);
    }
    expect(html("support/index.html")).toContain("26 letters and 10 digits");
  });

  test("support page names the contact and the four answers", () => {
    const page = html("support/index.html");
    expect(page).toContain(`mailto:${CONTACT}?subject=Morse%20Lamp`);
    for (const heading of ["no sound", "reset", "order", "offline"]) {
      expect(page.toLowerCase()).toMatch(new RegExp(`<h2[^>]*>[^<]*${heading}`));
    }
  });
});
