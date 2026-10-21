import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { APP_STORE_ID, CONTACT, GET_APP } from "../src/lib/site";

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

/** The page's stylesheet, resolved from the link tag the build wrote. */
function css(page: string): string {
  const match = html(page).match(/<link rel="stylesheet" href="([^"]+\.css)"/);
  expect(match, `${page} links no stylesheet`).not.toBeNull();
  return readFileSync(join(dist, match![1]), "utf8");
}

/** The stylesheet with every `@layer name { … }` block removed: what the cascade ranks above all layers. */
function unlayered(stylesheet: string): string {
  let out = "";
  let i = 0;
  while (i < stylesheet.length) {
    const open = stylesheet.indexOf("@layer ", i);
    const brace = open < 0 ? -1 : stylesheet.indexOf("{", open);
    const semicolon = open < 0 ? -1 : stylesheet.indexOf(";", open);
    if (open < 0 || brace < 0 || (semicolon >= 0 && semicolon < brace)) {
      out += stylesheet.slice(i, open < 0 ? stylesheet.length : semicolon + 1);
      i = open < 0 ? stylesheet.length : semicolon + 1;
      continue;
    }
    out += stylesheet.slice(i, open);
    let depth = 1;
    let j = brace + 1;
    for (; j < stylesheet.length && depth > 0; j++) {
      if (stylesheet[j] === "{") depth++;
      else if (stylesheet[j] === "}") depth--;
    }
    i = j;
  }
  return out;
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

  test("landing button joins the TestFlight beta", () => {
    expect(GET_APP).toEqual({
      label: "Join the TestFlight",
      href: "https://testflight.apple.com/join/w4vFmtRW",
    });
  });

  test("every page carries the Smart App Banner for the App Store record", () => {
    expect(APP_STORE_ID).toMatch(/^\d+$/);
    for (const page of pages) {
      expect(html(page)).toContain(`<meta name="apple-itunes-app" content="app-id=${APP_STORE_ID}">`);
    }
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

  test("the site's own rules sit in cascade layers so utility colours win", () => {
    // An unlayered `a { color: inherit }` outranks `text-white` in @layer utilities whatever the
    // order, so the landing button read black on blue in the light theme.
    const bare = unlayered(css("index.html"));
    expect(bare).not.toMatch(/(^|[{};,])a\{[^}]*color:/);
    expect(bare).not.toMatch(/\.prose-lamp/);
  });
});
