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
    const open = stylesheet.indexOf("@layer", i);
    if (open < 0) return out + stylesheet.slice(i);
    const brace = stylesheet.indexOf("{", open);
    const semicolon = stylesheet.indexOf(";", open);
    if (brace < 0 && semicolon < 0) throw new Error(`unterminated @layer at ${open}`);
    if (brace < 0 || (semicolon >= 0 && semicolon < brace)) {
      // `@layer a, b;` orders layers and holds no rules: keep it.
      out += stylesheet.slice(i, semicolon + 1);
      i = semicolon + 1;
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

  test("every rule the site writes itself sits in a cascade layer", () => {
    // An unlayered rule outranks `@layer utilities` whatever the source order, so a bare
    // `a { color: inherit }` once turned the landing button's text black in the light theme.
    // Above the layers only the theme's custom properties and the font and property at-rules belong.
    for (const page of pages) {
      const bare = unlayered(css(page));
      expect(bare).toContain(":root{color-scheme:");
      const rest = bare
        .replace(/@font-face\{[^}]*\}/g, "")
        .replace(/@property [^{]+\{[^}]*\}/g, "")
        .replace(/@media[^{]*\{:root\{[^}]*\}\}/g, "")
        .replace(/:root\{[^}]*\}/g, "")
        .replace(/@layer [a-z, ]+;/g, "")
        .trim();
      expect(rest, `${page} styles outside the layers: ${rest.slice(0, 200)}`).toBe("");
    }
  });
});
