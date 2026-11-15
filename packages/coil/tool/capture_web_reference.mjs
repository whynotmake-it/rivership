// Captures reference screenshots of components from the live docs site
// (https://www.fluidfunctionalism.com) so the Flutter port's golden tests can
// be compared against them. Output: ../test/goldens/web_reference/*.png plus
// measurements.json (computed styles / sizes sampled at capture time).
//
// How to run (do NOT npm install inside this repo; ESM ignores NODE_PATH, so
// copy the script next to a scratch node_modules and point OUT_DIR back here):
//   mkdir -p /tmp/webref && cd /tmp/webref && npm init -y && npm i playwright@1.64.0
//   # playwright 1.64.0 bundles chromium revision 1248 (already in
//   # ~/Library/Caches/ms-playwright on this machine); else: npx playwright install chromium
//   cp <repo>/packages/coil/tool/capture_web_reference.mjs /tmp/webref/
//   OUT_DIR=<repo>/packages/coil/test/goldens/web_reference \
//     node /tmp/webref/capture_web_reference.mjs
// A full run (8 jobs x 2 themes) takes ~5 minutes.
//
// Env:
//   OUT_DIR  output directory (default: ../test/goldens/web_reference next to this file)
//   ONLY     comma-separated job names to run (button,button-compact,switch,...)
//   THEMES   comma-separated themes (default light,dark)
//
// Theme is forced with the site's own `ff_theme` cookie (the server renders
// <html class="light|dark">) plus Playwright's colorScheme emulation; compact
// size uses the `ff_size=compact` cookie. All site settings are otherwise at
// their defaults (Base UI primitives, sharp radius, blue accent, Untitled UI icons).
// The site rate-limits bursts of requests (Vercel 403), so navigations are
// spaced out and a 403 triggers a long back-off + retry.

import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = process.env.OUT_DIR ?? path.resolve(HERE, '../test/goldens/web_reference');
const BASE = 'https://www.fluidfunctionalism.com';
const THEMES = (process.env.THEMES ?? 'light,dark').split(',');
const ONLY = process.env.ONLY?.split(',');
fs.mkdirSync(OUT, { recursive: true });

const measurementsPath = path.join(OUT, 'measurements.json');
const measurements = fs.existsSync(measurementsPath)
  ? JSON.parse(fs.readFileSync(measurementsPath, 'utf8'))
  : {};
const files = [];
const failures = [];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function open(page, slug) {
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await page.goto(`${BASE}/docs/${slug}`, { waitUntil: 'load', timeout: 60000 });
    if (res && res.status() === 403) {
      console.warn(`403 on ${slug}, backing off`);
      await sleep(120000);
      continue;
    }
    await page.waitForSelector('[data-component-preview]', { timeout: 30000 });
    await page.evaluate(() => document.fonts.ready);
    await sleep(2500); // hydration + mount animations
    await page.mouse.move(0, 0);
    return;
  }
  throw new Error(`could not load ${slug}`);
}

// The demo area of the Nth ComponentPreview (without its Preview/Code header).
function stage(page, i) {
  return page.locator('[data-component-preview]').nth(i).locator('[data-preview-stage]');
}

async function shot(loc, name, theme) {
  const file = `${name}__${theme}.png`;
  try {
    await loc.scrollIntoViewIfNeeded();
    await sleep(150);
    await loc.screenshot({ path: path.join(OUT, file), animations: 'disabled', caret: 'hide' });
    files.push(file);
    console.log('  saved', file);
  } catch (e) {
    failures.push(`${file}: ${e.message.split('\n')[0]}`);
    console.warn('  FAILED', file, e.message.split('\n')[0]);
  }
}

// Same as shot() but keeps running animations/transitions (needed while a
// pointer is held down: 'disabled' would not change that, but keeps hover
// transitions live-finished). Used for pressed states.
async function shotLive(loc, name, theme) {
  const file = `${name}__${theme}.png`;
  try {
    await loc.screenshot({ path: path.join(OUT, file), caret: 'hide' });
    files.push(file);
    console.log('  saved', file);
  } catch (e) {
    failures.push(`${file}: ${e.message.split('\n')[0]}`);
  }
}

// Keyboard focus so :focus-visible applies: focus the target, step back with
// Shift+Tab and forward again with Tab.
async function keyboardFocus(page, loc) {
  await loc.focus();
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Tab');
  await sleep(300);
  return loc.evaluate((el) => el === document.activeElement && el.matches(':focus-visible'));
}

async function press(page, loc) {
  const box = await loc.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await sleep(250);
  await page.mouse.down();
  await sleep(250);
}

async function release(page) {
  await page.mouse.up();
  await page.mouse.move(0, 0);
  await sleep(300);
}

// Computed-style snapshot of an element and its direct children.
async function measure(loc) {
  return loc.evaluate((el) => {
    const pick = (e) => {
      const cs = getComputedStyle(e);
      const r = e.getBoundingClientRect();
      return {
        tag: e.tagName.toLowerCase(),
        cls: (e.getAttribute('class') || '').slice(0, 200),
        w: +r.width.toFixed(2),
        h: +r.height.toFixed(2),
        bg: cs.backgroundColor,
        color: cs.color,
        border: `${cs.borderTopWidth} ${cs.borderTopStyle} ${cs.borderTopColor}`,
        radius: cs.borderRadius,
        boxShadow: cs.boxShadow,
        outline: `${cs.outlineWidth} ${cs.outlineStyle} ${cs.outlineColor} offset ${cs.outlineOffset}`,
        opacity: cs.opacity,
        transform: cs.transform,
        font: `${cs.fontSize}/${cs.lineHeight} ${cs.fontFamily.split(',')[0]} ${cs.fontVariationSettings}`,
        padding: cs.padding,
      };
    };
    return { self: pick(el), children: [...el.children].map(pick) };
  });
}

function record(theme, key, value) {
  measurements[theme] ??= {};
  measurements[theme][key] = value;
}

// ---------------------------------------------------------------------------

const jobs = {
  async button(page, t) {
    await open(page, 'button');
    const variants = stage(page, 1);
    await shot(stage(page, 0), 'button__playground_primary', t);
    await shot(variants, 'button__variants', t);
    await shot(stage(page, 2), 'button__icons', t);
    await shot(stage(page, 3), 'button__loading_disabled', t);

    const row = variants.locator('button');
    const names = ['primary', 'secondary', 'tertiary', 'ghost', 'destructive'];
    for (let i = 0; i < 5; i++) record(t, `button.default.${names[i]}.rest`, await measure(row.nth(i)));
    record(t, 'button.disabled.rest', await measure(stage(page, 3).locator('button').nth(2)));
    record(t, 'button.loading.rest', await measure(stage(page, 3).locator('button').nth(1)));

    // Hover each inline variant (only the first row), screenshot the grid with primary hovered.
    for (let i = 0; i < 5; i++) {
      await row.nth(i).hover();
      await sleep(400);
      record(t, `button.default.${names[i]}.hover`, await measure(row.nth(i)));
      if (i === 0 || i === 1 || i === 3) await shot(variants, `button__hover_${names[i]}`, t);
    }
    // Pressed (mouse held down).
    for (const i of [0, 1, 3]) {
      await press(page, row.nth(i));
      record(t, `button.default.${names[i]}.pressed`, await measure(row.nth(i)));
      await shotLive(variants, `button__pressed_${names[i]}`, t);
      await release(page);
    }
    // Keyboard focus.
    await page.mouse.move(0, 0);
    const fv = await keyboardFocus(page, row.nth(0));
    record(t, 'button.default.primary.focusVisible', { ...(await measure(row.nth(0))), focusVisible: fv });
    await shot(variants, 'button__focus_primary', t);
    await keyboardFocus(page, row.nth(2));
    record(t, 'button.default.tertiary.focusVisible', await measure(row.nth(2)));
    await page.evaluate(() => document.activeElement?.blur());

    // Icon-only via the right-hand "Playground variant" panel.
    try {
      const toggle = page
        .locator('text=Icon only')
        .first()
        .locator('xpath=ancestor::*[.//*[@role="switch"]][1]')
        .locator('[role="switch"]')
        .first();
      await toggle.evaluate((el) => el.click()); // DOM click: a sticky overlay can intercept pointer clicks
      await sleep(600);
      await page.mouse.move(0, 0);
      await sleep(300);
      record(t, 'button.icon.primary.rest', await measure(stage(page, 0).locator('button').first()));
      await shot(stage(page, 0), 'button__playground_icon_only', t);
    } catch (e) {
      failures.push(`button icon-only (${t}): ${e.message.split('\n')[0]}`);
    }
  },

  async 'button-compact'(page, t) {
    await open(page, 'button');
    const variants = stage(page, 1);
    await shot(stage(page, 0), 'button__compact_playground_primary', t);
    await shot(variants, 'button__compact_variants', t);
    await shot(stage(page, 2), 'button__compact_icons', t);
    const row = variants.locator('button');
    record(t, 'button.compact.primary.rest', await measure(row.nth(0)));
    record(t, 'button.compact.secondary.rest', await measure(row.nth(1)));
    try {
      const toggle = page
        .locator('text=Icon only')
        .first()
        .locator('xpath=ancestor::*[.//*[@role="switch"]][1]')
        .locator('[role="switch"]')
        .first();
      await toggle.evaluate((el) => el.click()); // DOM click: a sticky overlay can intercept pointer clicks
      await sleep(600);
      await page.mouse.move(0, 0);
      await sleep(300);
      record(t, 'button.iconCompact.primary.rest', await measure(stage(page, 0).locator('button').first()));
      await shot(stage(page, 0), 'button__compact_playground_icon_only', t);
    } catch (e) {
      failures.push(`button compact icon-only (${t}): ${e.message.split('\n')[0]}`);
    }
  },

  async switch(page, t) {
    await open(page, 'switch');
    const basic = stage(page, 0);
    const sw = basic.locator('[role="switch"]');
    record(t, 'switch.off.rest', await measure(sw));
    await shot(basic, 'switch__off', t);
    await sw.hover();
    await sleep(400);
    record(t, 'switch.off.hover', await measure(sw));
    await shot(basic, 'switch__off_hover', t);
    await press(page, sw);
    record(t, 'switch.off.pressed', await measure(sw));
    await shotLive(basic, 'switch__off_pressed', t);
    await release(page); // completes the click -> on
    await sleep(500);
    if ((await sw.getAttribute('aria-checked')) !== 'true') await sw.click();
    await page.mouse.move(0, 0);
    await sleep(500);
    record(t, 'switch.on.rest', await measure(sw));
    await shot(basic, 'switch__on', t);
    await sw.hover();
    await sleep(400);
    record(t, 'switch.on.hover', await measure(sw));
    await shot(basic, 'switch__on_hover', t);
    await page.mouse.move(0, 0);
    const fv = await keyboardFocus(page, sw);
    record(t, 'switch.on.focusVisible', { ...(await measure(sw)), focusVisible: fv });
    await shot(basic, 'switch__on_focus', t);
    await page.evaluate(() => document.activeElement?.blur());
    const dis = stage(page, 1);
    record(t, 'switch.disabled', await measure(dis.locator('[role="switch"]')));
    await shot(dis, 'switch__disabled', t);
  },

  async checkbox(page, t) {
    await open(page, 'checkbox');
    const basic = stage(page, 0);
    const cb = basic.locator('[role="checkbox"]');
    record(t, 'checkbox.unchecked.rest', await measure(cb));
    await shot(basic, 'checkbox__unchecked', t);
    await cb.hover();
    await sleep(400);
    record(t, 'checkbox.unchecked.hover', await measure(cb));
    await shot(basic, 'checkbox__unchecked_hover', t);
    await press(page, cb);
    record(t, 'checkbox.unchecked.pressed', await measure(cb));
    await shotLive(basic, 'checkbox__unchecked_pressed', t);
    await release(page);
    if ((await cb.getAttribute('aria-checked')) !== 'true') await cb.click();
    await page.mouse.move(0, 0);
    await sleep(600);
    record(t, 'checkbox.checked.rest', await measure(cb));
    await shot(basic, 'checkbox__checked', t);
    const fv = await keyboardFocus(page, cb);
    record(t, 'checkbox.checked.focusVisible', { ...(await measure(cb)), focusVisible: fv });
    await shot(basic, 'checkbox__checked_focus', t);
    await page.evaluate(() => document.activeElement?.blur());
    await shot(stage(page, 1), 'checkbox__with_description_checked', t);
    const states = stage(page, 2);
    record(t, 'checkbox.invalid', await measure(states.locator('[role="checkbox"]').nth(0)));
    record(t, 'checkbox.checked.disabled', await measure(states.locator('[role="checkbox"]').nth(1)));
    await shot(states, 'checkbox__invalid_and_disabled', t);
  },

  async tabs(page, t) {
    await open(page, 'tabs');
    const names = ['basic', 'icons', 'active_label'];
    for (let i = 0; i < 3; i++) await shot(stage(page, i), `tabs__${names[i]}`, t);
    const basic = stage(page, 0);
    const list = basic.locator('[role="tablist"]');
    const tabs = list.locator('[role="tab"]');
    record(t, 'tabs.basic.tablist', await measure(list));
    record(t, 'tabs.basic.tab0', await measure(tabs.nth(0)));
    record(t, 'tabs.basic.tab1', await measure(tabs.nth(1)));
    await tabs.nth(1).hover();
    await sleep(400);
    record(t, 'tabs.basic.tablist.hoverTab1', await measure(list));
    await shot(basic, 'tabs__basic_hover_second', t);
    await press(page, tabs.nth(2));
    await shotLive(basic, 'tabs__basic_pressed_third', t);
    await release(page);
    await tabs.nth(2).click();
    await page.mouse.move(0, 0);
    await sleep(700);
    record(t, 'tabs.basic.tablist.selected2', await measure(list));
    await shot(basic, 'tabs__basic_third_selected', t);
    const fv = await keyboardFocus(page, tabs.nth(2));
    record(t, 'tabs.basic.tab2.focusVisible', { ...(await measure(tabs.nth(2))), focusVisible: fv });
    await shot(basic, 'tabs__basic_focus', t);
    await page.evaluate(() => document.activeElement?.blur());
    const al = stage(page, 2).locator('[role="tab"]');
    await al.nth(1).click();
    await page.mouse.move(0, 0);
    await sleep(800);
    await shot(stage(page, 2), 'tabs__active_label_second_selected', t);
  },

  async input(page, t) {
    await open(page, 'input');
    const basic = stage(page, 0);
    const input = basic.locator('input');
    record(t, 'input.placeholder.rest', await measure(input));
    await shot(basic, 'input__placeholder', t);
    await input.hover();
    await sleep(400);
    record(t, 'input.placeholder.hover', await measure(input));
    await shot(basic, 'input__hover', t);
    await page.mouse.move(0, 0);
    const fv = await keyboardFocus(page, input);
    record(t, 'input.focused', { ...(await measure(input)), focusVisible: fv });
    await shot(basic, 'input__focused_empty', t);
    await page.keyboard.type('ada@lovelace.dev');
    await sleep(200);
    await shot(basic, 'input__focused_filled', t);
    await page.evaluate(() => document.activeElement?.blur());
    await sleep(400);
    record(t, 'input.filled.rest', await measure(input));
    await shot(basic, 'input__filled', t);
    await shot(stage(page, 1), 'input__with_field', t);
    record(t, 'input.invalid', await measure(stage(page, 2).locator('input')));
    await shot(stage(page, 2), 'input__invalid', t);
    record(t, 'input.disabled', await measure(stage(page, 3).locator('input')));
    await shot(stage(page, 3), 'input__disabled', t);
    await shot(stage(page, 4), 'input__types', t);
  },

  async 'fluid-hover'(page, t) {
    await open(page, 'fluid-hover');
    const demo = stage(page, 0);
    const items = demo.locator('button', { hasText: /^(Inbox|Drafts|Sent|Archive|Trash)$/ });
    await shot(demo, 'fluid_hover__list_rest', t);
    // Left list = plain CSS :hover (items 0-4), right list = fluid hover (5-9).
    await items.nth(1).hover();
    await sleep(600);
    await shot(demo, 'fluid_hover__plain_hover_drafts', t);
    await items.nth(6).hover();
    await sleep(600);
    await shot(demo, 'fluid_hover__list_hover_drafts', t);
    // The highlight is a separate absolutely-positioned element; sample the
    // largest non-button sibling that overlaps the hovered item.
    record(
      t,
      'coilHover.highlight',
      await items.nth(6).evaluate((btn) => {
        const r = btn.getBoundingClientRect();
        const cands = [...btn.parentElement.parentElement.querySelectorAll('*')].filter((e) => {
          if (e.tagName === 'BUTTON' || e.contains(btn)) return false;
          const q = e.getBoundingClientRect();
          const cs = getComputedStyle(e);
          return Math.abs(q.top - r.top) < 4 && q.height > 10 && cs.backgroundColor !== 'rgba(0, 0, 0, 0)';
        });
        const item = getComputedStyle(btn);
        return {
          item: { h: r.height, w: r.width, color: item.color, font: `${item.fontSize}/${item.lineHeight}`, padding: item.padding },
          highlight: cands.map((e) => {
            const cs = getComputedStyle(e);
            const q = e.getBoundingClientRect();
            return { w: q.width, h: q.height, bg: cs.backgroundColor, radius: cs.borderRadius, opacity: cs.opacity, cls: e.getAttribute('class') };
          }),
        };
      }),
    );
    await items.nth(8).hover();
    await sleep(600);
    await shot(demo, 'fluid_hover__list_hover_archive', t);
    await press(page, items.nth(8));
    await shotLive(demo, 'fluid_hover__list_pressed_archive', t);
    await release(page);
    await page.mouse.move(0, 0);
    await sleep(400);
    // "3 axes" demo: hover the second tab of the x strip and "Drafts" in the y list.
    const axes = stage(page, 2);
    await axes.scrollIntoViewIfNeeded();
    // Raw mouse moves: the demo's layered markup makes Playwright's
    // actionability check for .hover() time out.
    const moveTo = async (loc) => {
      const box = await loc.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 5 });
    };
    await moveTo(axes.getByText('Recents', { exact: true }).first());
    await sleep(600);
    await shot(axes, 'fluid_hover__three_axes_hover_x', t);
    await moveTo(axes.getByText('Drafts', { exact: true }).first());
    await sleep(600);
    await shot(axes, 'fluid_hover__three_axes_hover_y', t);
  },

  async sizes(page, t) {
    await open(page, 'sizes');
    // "The principle": default (36px) and compact (28px) toolbars stacked.
    await shot(stage(page, 0), 'sizes__default_vs_compact_toolbar', t);
    // "Compact regions": its own frame with a Default/Compact tab toggle.
    const region = page
      .locator('[data-keyboard-scope]:not([data-component-preview])')
      .filter({ has: page.locator('[role="tab"]', { hasText: 'Compact' }) })
      .first();
    if (await region.count()) {
      await shot(region, 'sizes__compact_region_compact', t);
      await region.locator('[role="tab"]', { hasText: 'Default' }).first().click();
      await page.mouse.move(0, 0);
      await sleep(900);
      await shot(region, 'sizes__compact_region_default', t);
    } else {
      failures.push(`sizes compact-region frame not found (${t})`);
    }
  },
};

const jobCookies = { 'button-compact': [{ name: 'ff_size', value: 'compact' }] };

const browser = await chromium.launch();
try {
  for (const t of THEMES) {
    for (const [name, fn] of Object.entries(jobs)) {
      if (ONLY && !ONLY.includes(name)) continue;
      console.log(`== ${name} (${t})`);
      const ctx = await browser.newContext({
        viewport: { width: 1280, height: 900 },
        deviceScaleFactor: 2,
        colorScheme: t,
        reducedMotion: 'no-preference',
      });
      await ctx.addCookies(
        [{ name: 'ff_theme', value: t }, ...(jobCookies[name] ?? [])].map((c) => ({
          ...c,
          domain: 'www.fluidfunctionalism.com',
          path: '/',
        })),
      );
      const page = await ctx.newPage();
      try {
        await fn(page, t);
        const cls = await page.evaluate(() => document.documentElement.className);
        if (!cls.split(/\s+/).includes(t)) failures.push(`${name} (${t}): <html> class was "${cls}"`);
      } catch (e) {
        failures.push(`${name} (${t}): ${e.message.split('\n')[0]}`);
        console.warn('JOB FAILED', name, t, e.message);
      }
      await ctx.close();
      fs.writeFileSync(measurementsPath, JSON.stringify(measurements, null, 2));
      await sleep(6000); // stay under the site's rate limit
    }
  }
} finally {
  await browser.close();
}
console.log(`\n${files.length} files`);
if (failures.length) console.log('Failures:\n' + failures.join('\n'));
