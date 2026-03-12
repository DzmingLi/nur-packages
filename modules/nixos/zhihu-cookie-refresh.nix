{ config, lib, pkgs, ... }:

let
  cfg = config.services.zhihu-cookie-refresh;

  playwright-browsers = pkgs.playwright-driver.passthru.browsers-chromium;
  chromiumRevision = pkgs.playwright-driver.passthru.browsersJSON.chromium.revision;
  chromiumPath = "${playwright-browsers}/chromium-${chromiumRevision}/chrome-linux64/chrome";

  refreshScript = pkgs.writeText "zhihu-cookie-refresh.js" ''
    const { chromium } = require('${pkgs.playwright-driver}');
    const { readFileSync, writeFileSync, mkdirSync } = require('fs');
    const { spawn } = require('child_process');
    const { createInterface } = require('readline');
    const { dirname, join } = require('path');
    const crypto = require('crypto');

    const fallbackSeedCookies = ${builtins.toJSON cfg.seedCookies};
    const envFile = process.env.ENV_FILE;
    const feedsConfig = ${builtins.toJSON cfg.feeds};
    const outputDir = process.env.OUTPUT_DIR || "";

    // ========== Cookie helpers ==========

    function getSeedCookies() {
      try {
        const content = readFileSync(envFile, 'utf8');
        const match = content.match(/ZHIHU_COOKIES='(.+)'/);
        if (match && match[1].includes('z_c0=')) {
          console.log('Using cookies from previous refresh');
          return match[1].replace(/'\\'''/g, "'");
        }
      } catch {}
      console.log('Using fallback seed cookies');
      return fallbackSeedCookies;
    }

    function getCookieValue(cookieStr, key) {
      const pairs = cookieStr.split(';').map(s => s.trim());
      const found = pairs.find(p => p.startsWith(key + '='));
      return found ? found.slice(key.length + 1) : "";
    }

    // ========== x-zse-96 signing (ported from RSSHub) ==========

    function md5(str) {
      return crypto.createHash('md5').update(str).digest('hex');
    }

    function _i(e, t, n) {
      t[n] = 255 & (e >>> 24);
      t[n + 1] = 255 & (e >>> 16);
      t[n + 2] = 255 & (e >>> 8);
      t[n + 3] = 255 & e;
    }
    function _B(e, t) {
      return ((255 & e[t]) << 24) | ((255 & e[t + 1]) << 16) | ((255 & e[t + 2]) << 8) | (255 & e[t + 3]);
    }
    function _Q(e, t) {
      return ((4294967295 & e) << t) | (e >>> (32 - t));
    }
    const _h = {
      zk: [1170614578,1024848638,1413669199,-343334464,-766094290,-1373058082,-143119608,-297228157,1933479194,-971186181,-406453910,460404854,-547427574,-1891326262,-1679095901,2119585428,-2029270069,2035090028,-1521520070,-5587175,-77751101,-2094365853,-1243052806,1579901135,1321810770,456816404,-1391643889,-229302305,330002838,-788960546,363569021,-1947871109],
      zb: [20,223,245,7,248,2,194,209,87,6,227,253,240,128,222,91,237,9,125,157,230,93,252,205,90,79,144,199,159,197,186,167,39,37,156,198,38,42,43,168,217,153,15,103,80,189,71,191,97,84,247,95,36,69,14,35,12,171,28,114,178,148,86,182,32,83,158,109,22,255,94,238,151,85,77,124,254,18,4,26,123,176,232,193,131,172,143,142,150,30,10,146,162,62,224,218,196,229,1,192,213,27,110,56,231,180,138,107,242,187,54,120,19,44,117,228,215,203,53,239,251,127,81,11,133,96,204,132,41,115,73,55,249,147,102,48,122,145,106,118,74,190,29,16,174,5,177,129,63,113,99,31,161,76,246,34,211,13,60,68,207,160,65,111,82,165,67,169,225,57,112,244,155,51,236,200,233,58,61,47,100,137,185,64,17,70,234,163,219,108,170,166,59,149,52,105,24,212,78,173,45,0,116,226,119,136,206,135,175,195,25,92,121,208,126,139,3,75,141,21,130,98,241,40,154,66,184,49,181,46,243,88,101,183,8,23,72,188,104,179,210,134,250,201,164,89,216,202,220,50,221,152,140,33,235,214],
    };
    function _G(e) {
      const t = Array.from({ length: 4 });
      const n = Array.from({ length: 4 });
      _i(e, t, 0);
      n[0] = _h.zb[255 & t[0]];
      n[1] = _h.zb[255 & t[1]];
      n[2] = _h.zb[255 & t[2]];
      n[3] = _h.zb[255 & t[3]];
      const r = _B(n, 0);
      return r ^ _Q(r, 2) ^ _Q(r, 10) ^ _Q(r, 18) ^ _Q(r, 24);
    }
    const __g = {
      x(e, t) {
        let n = [];
        for (let r = e.length, ii = 0; 0 < r; r -= 16) {
          const a = Array.from({ length: 16 });
          const o = e.slice(16 * ii, 16 * (ii + 1));
          for (let c = 0; c < 16; c++) a[c] = o[c] ^ t[c];
          t = __g.r(a);
          n = n.concat(t);
          ii++;
        }
        return n;
      },
      r(e) {
        const t = Array.from({ length: 16 });
        const n = Array.from({ length: 36 });
        n[0] = _B(e, 0); n[1] = _B(e, 4); n[2] = _B(e, 8); n[3] = _B(e, 12);
        for (let r = 0; r < 32; r++) {
          const o = _G(n[r + 1] ^ n[r + 2] ^ n[r + 3] ^ _h.zk[r]);
          n[r + 4] = n[r] ^ o;
        }
        _i(n[35], t, 0); _i(n[34], t, 4); _i(n[33], t, 8); _i(n[32], t, 12);
        return t;
      },
    };
    function g_encrypt(md5Str) {
      const salt = '6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE';
      function encode(param) {
        let result = "";
        for (const x of [0, 6, 12, 18]) result += salt.charAt((param >>> x) & 63);
        return result;
      }
      const arr = [];
      for (let ii = 0; ii < md5Str.length; ii++) arr.push(md5Str.charCodeAt(ii));
      arr.unshift(0);
      arr.unshift(Math.floor(Math.random() * 127));
      for (let ii = 0; ii < 15; ii++) arr.push(14);
      const front = arr.slice(0, 16);
      const fixArr = [48,53,57,48,53,51,102,55,100,49,53,101,48,49,100,55];
      const xored = [];
      for (let ii = 0; ii < front.length; ii++) xored.push(front[ii] ^ fixArr[ii] ^ 42);
      const gr = __g.r(xored);
      const back = arr.slice(16, 48);
      const gx = __g.x(back, gr);
      const processed = gr.concat(gx);
      let current = 0;
      let resultStr = "";
      for (let ii = 0; ii < processed.length; ii++) {
        const pop = processed[processed.length - ii - 1];
        const a = 8 * (ii % 4);
        const b = 58 >>> a;
        const c = b & 255;
        current |= (pop ^ c) << (8 * (ii % 3));
        if (ii % 3 === 2) { resultStr += encode(current); current = 0; }
      }
      return resultStr;
    }

    // Exactly like RSSHub utils.ts getSignedHeader
    function getSignedHeaders(apiPath, cookieStr) {
      const dc0 = getCookieValue(cookieStr, 'd_c0');
      const xzse93 = '101_3_3.0';
      const f = xzse93 + '+' + apiPath + '+' + dc0;
      const xzse96 = '2.0_' + g_encrypt(md5(f));
      return { 'x-zse-96': xzse96, 'x-zse-93': xzse93, 'x-app-za': 'OS=Web' };
    }

    // ========== Chromium launcher ==========

    function launchChromium() {
      return new Promise((resolve, reject) => {
        const proc = spawn(process.env.CHROMIUM_EXEC_PATH, [
          '--remote-debugging-port=0', '--no-first-run', '--no-sandbox',
          '--disable-setuid-sandbox', '--disable-dev-shm-usage',
          '--proxy-server=direct://', '--window-size=1920,1080', '--lang=zh-CN',
          '--disable-blink-features=AutomationControlled',
          '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
          'about:blank',
        ], { stdio: ['pipe', 'pipe', 'pipe'] });
        const rl = createInterface({ input: proc.stderr });
        const timer = setTimeout(() => reject(new Error('Chromium launch timeout')), 15000);
        rl.on('line', line => {
          const m = line.match(/DevTools listening on (ws:\/\/.*)/);
          if (m) { clearTimeout(timer); rl.close(); resolve({ proc, wsEndpoint: m[1] }); }
        });
        proc.on('error', e => { clearTimeout(timer); reject(e); });
      });
    }

    // ========== RSS XML ==========

    function escapeXml(s) {
      return String(s == null ? "" : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function toRssXml(feed) {
      let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0">\n<channel>\n';
      xml += '<title>' + escapeXml(feed.title) + '</title>\n';
      xml += '<link>' + escapeXml(feed.link) + '</link>\n';
      xml += '<description>' + escapeXml(feed.description) + '</description>\n';
      xml += '<lastBuildDate>' + new Date().toUTCString() + '</lastBuildDate>\n';
      for (const item of feed.items) {
        xml += '<item>\n';
        xml += '<title>' + escapeXml(item.title) + '</title>\n';
        xml += '<link>' + escapeXml(item.link) + '</link>\n';
        if (item.guid) xml += '<guid isPermaLink="false">' + escapeXml(item.guid) + '</guid>\n';
        if (item.description) xml += '<description><![CDATA[' + item.description.replace(/]]>/g, ']]&gt;') + ']]></description>\n';
        if (item.pubDate) xml += '<pubDate>' + item.pubDate + '</pubDate>\n';
        if (item.author) xml += '<author>' + escapeXml(item.author) + '</author>\n';
        xml += '</item>\n';
      }
      xml += '</channel>\n</rss>\n';
      return xml;
    }

    // ========== Node.js HTTPS request (like RSSHub's ofetch) ==========

    const https = require('https');

    function zhihuGet(apiPath, cookieStr, referer) {
      const signedHeaders = getSignedHeaders(apiPath, cookieStr);
      const headers = {
        "x-api-version": "3.0.91",
        "x-zse-96": signedHeaders["x-zse-96"],
        "x-zse-93": signedHeaders["x-zse-93"],
        "x-app-za": "OS=Web",
        "cookie": cookieStr,
        "Referer": referer,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      };
      const url = "https://www.zhihu.com" + apiPath;
      console.log("GET", url.substring(0, 120));
      return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const req = https.request({
          hostname: urlObj.hostname,
          path: urlObj.pathname + urlObj.search,
          method: "GET",
          headers: headers,
        }, (res) => {
          let data = "";
          res.on("data", chunk => data += chunk);
          res.on("end", () => {
            console.log("Response:", res.statusCode, data.substring(0, 200));
            if (res.statusCode !== 200) {
              resolve({ _error: res.statusCode, _body: data.substring(0, 300) });
            } else {
              try { resolve(JSON.parse(data)); }
              catch { resolve({ _error: "parse_error", _body: data.substring(0, 300) }); }
            }
          });
        });
        req.on("error", e => reject(e));
        req.end();
      });
    }

    // Get user profile via SSR page (like RSSHub posts.ts)
    function zhihuGetProfile(cookieStr, usertype, userId) {
      const pageApiPath = "/" + (usertype === "org" ? "org" : "people") + "/" + userId;
      const signedHeaders = getSignedHeaders(pageApiPath, cookieStr);
      const referer = "https://www.zhihu.com/" + usertype + "/" + userId + "/";
      const headers = {
        "x-api-version": "3.0.91",
        "x-zse-96": signedHeaders["x-zse-96"],
        "x-zse-93": signedHeaders["x-zse-93"],
        "x-app-za": "OS=Web",
        "cookie": cookieStr,
        "Referer": referer,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      };
      const url = "https://www.zhihu.com" + pageApiPath;
      console.log("GET profile:", url);
      return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const req = https.request({
          hostname: urlObj.hostname,
          path: urlObj.pathname,
          method: "GET",
          headers: headers,
        }, (res) => {
          let data = "";
          res.on("data", chunk => data += chunk);
          res.on("end", () => {
            if (res.statusCode !== 200) { resolve(null); return; }
            const match = data.match(/id="js-initialData"[^>]*>(.*?)<\/script/s);
            if (!match) { resolve(null); return; }
            try {
              const json = JSON.parse(match[1]);
              const users = json.initialState && json.initialState.entities && json.initialState.entities.users;
              resolve((users && users[userId]) || null);
            } catch { resolve(null); }
          });
        });
        req.on("error", () => resolve(null));
        req.end();
      });
    }

    // ========== Posts scraper (follows RSSHub posts.ts exactly) ==========

    async function scrapePosts(usertype, userId, cookieStr) {
      const prefix = usertype === "org" ? "org" : "people";
      const apiPrefix = usertype === "org" ? "org" : "members";
      console.log("Scraping posts: /" + prefix + "/" + userId);

      // Get profile (like RSSHub)
      const profile = await zhihuGetProfile(cookieStr, usertype, userId);
      const userName = (profile && profile.name) || userId;

      // Articles API (identical to RSSHub posts.ts)
      const articleParams = new URLSearchParams({
        include: "data[*].comment_count,suggest_edit,is_normal,thumbnail_extra_info,thumbnail,can_comment,comment_permission,admin_closed_comment,content,voteup_count,created,updated,upvoted_followees,voting,review_info,reaction_instruction,is_labeled,label_info;data[*].vessay_info;data[*].author.badge[?(type=best_answerer)].topics;data[*].author.vip_info;",
        offset: "0",
        limit: "20",
        sort_by: "created",
      });
      const apiPath = "/api/v4/" + apiPrefix + "/" + userId + "/articles?" + articleParams.toString();
      const referer = "https://www.zhihu.com/" + usertype + "/" + userId + "/posts";

      const resp = await zhihuGet(apiPath, cookieStr, referer);

      if (resp && resp._error) {
        console.error("Articles API error:", resp._error, resp._body || "");
        return null;
      }
      if (!resp || !Array.isArray(resp.data)) {
        console.error("Unexpected articles response");
        return null;
      }

      const items = resp.data.map(a => ({
        title: a.title,
        link: "https://zhuanlan.zhihu.com/p/" + a.id,
        description: a.content || "",
        pubDate: a.created ? new Date(a.created * 1000).toUTCString() : "",
        author: (a.author && a.author.name) || userName,
        guid: "zhihu-article-" + a.id,
      }));

      console.log("Got " + items.length + " articles for " + userName);
      return items.length > 0 ? {
        title: userName + " 的知乎文章",
        link: referer,
        description: (profile && profile.headline) || "",
        items,
      } : null;
    }

    // ========== Answers scraper (follows RSSHub answers.ts exactly) ==========

    async function scrapeAnswers(userId, cookieStr) {
      console.log("Scraping answers: /people/" + userId);

      // Answers API (identical to RSSHub answers.ts — raw string, not URLSearchParams)
      const apiPath = "/api/v4/members/" + userId + "/answers?limit=7&include=data[*].is_normal,content";
      const referer = "https://www.zhihu.com/people/" + userId + "/activities";

      const resp = await zhihuGet(apiPath, cookieStr, referer);

      if (resp && resp._error) {
        console.error("Answers API error:", resp._error, resp._body || "");
        return null;
      }
      if (!resp || !Array.isArray(resp.data)) {
        console.error("Unexpected answers response");
        return null;
      }

      const items = resp.data.map(a => ({
        title: (a.question && a.question.title) || "",
        link: "https://www.zhihu.com/question/" + (a.question && a.question.id) + "/answer/" + a.id,
        description: a.content || "",
        pubDate: a.created_time ? new Date(a.created_time * 1000).toUTCString() : "",
        author: (a.author && a.author.name) || userId,
        guid: "zhihu-answer-" + a.id,
      })).filter(i => i.title);

      const authorName = (resp.data[0] && resp.data[0].author && resp.data[0].author.name) || userId;
      console.log("Got " + items.length + " answers for " + authorName);
      return items.length > 0 ? {
        title: authorName + " 的知乎回答",
        link: "https://www.zhihu.com/people/" + userId + "/answers",
        description: "",
        items,
      } : null;
    }

    // ========== Main ==========

    (async () => {
      const seedCookies = getSeedCookies();

      if (!seedCookies || !seedCookies.includes('z_c0=')) {
        console.log('No valid seed cookies (missing z_c0). Skipping.');
        process.exit(0);
      }

      console.log('Launching Chromium...');
      const { proc, wsEndpoint } = await launchChromium();
      console.log('Connected via CDP');

      let browser;
      try {
        browser = await chromium.connectOverCDP(wsEndpoint);
        const context = browser.contexts()[0] || await browser.newContext();

        const cookiePairs = seedCookies.split(';').map(s => s.trim()).filter(Boolean);
        const cookieObjects = cookiePairs.map(pair => {
          const idx = pair.indexOf('=');
          return { name: pair.substring(0, idx), value: pair.substring(idx + 1), domain: '.zhihu.com', path: '/' };
        });
        await context.addCookies(cookieObjects);

        const page = context.pages()[0] || await context.newPage();

        const cdp = await context.newCDPSession(page);
        await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
          source: 'Object.defineProperty(navigator, "webdriver", {get: () => false});',
        });

        // --- Cookie refresh ---
        await page.goto('https://www.zhihu.com/explore', { waitUntil: 'networkidle', timeout: 30000 });
        console.log('Page URL:', page.url());

        if (page.url().includes('unhuman')) {
          console.error('Anti-bot triggered');
          process.exit(2);
        }

        let zseCk = null;
        const initCk = await page.evaluate(() => document.cookie.match(/__zse_ck=([^;]+)/)?.[1]);
        if (initCk) { zseCk = initCk; console.log('Got __zse_ck from page JS'); }

        if (!zseCk) {
          console.log('Injecting v3.js...');
          await page.addScriptTag({ url: 'https://static.zhihu.com/zse-ck/v3.js' });
          try {
            await page.waitForFunction("document.cookie.includes('__zse_ck')", { timeout: 15000 });
            zseCk = await page.evaluate(() => document.cookie.match(/__zse_ck=([^;]+)/)?.[1]);
            if (zseCk) console.log('Got __zse_ck after v3.js');
          } catch {}
        }

        if (!zseCk) {
          try {
            zseCk = await page.evaluate(() => typeof __g !== 'undefined' && __g.ck ? __g.ck : null);
            if (zseCk) console.log('Got __zse_ck from __g.ck');
          } catch {}
        }

        if (!zseCk) { console.error('Failed to get __zse_ck'); process.exit(1); }
        console.log('__zse_ck:', zseCk.substring(0, 20) + '...');

        // Merge cookies
        const seedMap = new Map();
        cookiePairs.forEach(pair => {
          const idx = pair.indexOf('=');
          if (idx > 0) seedMap.set(pair.substring(0, idx), pair.substring(idx + 1));
        });
        const browserCookies = await context.cookies('https://www.zhihu.com');
        browserCookies.forEach(c => {
          // Playwright strips quotes from cookie values, but d_c0 needs quotes preserved
          // (Zhihu Set-Cookie sends d_c0="value" and signing requires the quoted form)
          if (c.name === 'd_c0' && !c.value.startsWith('"')) {
            seedMap.set(c.name, '"' + c.value + '"');
          } else {
            seedMap.set(c.name, c.value);
          }
        });
        seedMap.set('__zse_ck', zseCk);

        if (!seedMap.has('z_c0')) { console.error('Lost z_c0'); process.exit(1); }

        const cookieStr = Array.from(seedMap.entries()).map(([k, v]) => k + '=' + v).join('; ');
        console.log('Merged', seedMap.size, 'cookies');

        writeFileSync(envFile,
          "ZHIHU_COOKIES='" + cookieStr.replace(/'/g, "'\\'''") + "'\n",
          { mode: 0o600 });
        console.log('Wrote cookies to env file');

        // --- Feed scraping ---
        if (feedsConfig.length > 0 && outputDir) {
          console.log('Scraping ' + feedsConfig.length + ' feed(s)...');
          for (const feed of feedsConfig) {
            try {
              await new Promise(r => setTimeout(r, 2000));
              let result = null;
              if (feed.type === 'posts') {
                result = await scrapePosts(feed.usertype || 'people', feed.id, cookieStr);
              } else if (feed.type === 'answers') {
                result = await scrapeAnswers(feed.id, cookieStr);
              } else {
                console.error('Unknown feed type: ' + feed.type);
                continue;
              }
              if (result && result.items.length > 0) {
                const outPath = join(outputDir, feed.output);
                mkdirSync(dirname(outPath), { recursive: true });
                writeFileSync(outPath, toRssXml(result), { mode: 0o644 });
                console.log('Wrote ' + result.items.length + ' items to ' + outPath);
              } else {
                console.error('No data for ' + feed.type + '/' + (feed.id || ""));
              }
            } catch (e) {
              console.error('Feed ' + feed.type + '/' + (feed.id || "") + ' failed:', e.message);
            }
          }
        }
      } finally {
        if (browser) await browser.close().catch(() => {});
        proc.kill('SIGTERM');
      }
    })().catch(e => { console.error(e); process.exit(1); });
  '';
in
{
  options.services.zhihu-cookie-refresh = {
    enable = lib.mkEnableOption "Zhihu cookie refresh and feed scraping via headless Chromium";

    seedCookies = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Fallback seed cookies (semicolon-separated) for the first run only.
        Must include at least `z_c0` for authenticated access.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/rsshub/zhihu-cookies.env";
      description = "Path to write the ZHIHU_COOKIES env file.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "rsshub";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rsshub";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "How often to refresh cookies and scrape feeds.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional OnCalendar schedule (overrides interval).";
    };

    initialDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
    };

    restartService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "rsshub.service";
      description = "Service to restart after cookie refresh. null to disable.";
    };

    feeds = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [ "posts" "answers" ];
            description = "posts (用户文章) or answers (用户回答).";
          };
          id = lib.mkOption {
            type = lib.types.str;
            description = "User url_token (from profile URL).";
          };
          usertype = lib.mkOption {
            type = lib.types.enum [ "people" "org" ];
            default = "people";
            description = "people or org (for posts only).";
          };
          output = lib.mkOption {
            type = lib.types.str;
            description = "Output path relative to outputDir.";
          };
        };
      });
      default = [];
      description = "Zhihu feeds to scrape after cookie refresh.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/zhihu-feeds";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "f ${cfg.envFile} 0600 ${cfg.user} ${cfg.group} -"
    ] ++ lib.optionals (cfg.feeds != []) [
      "d ${cfg.outputDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.zhihu-cookie-refresh = {
      description = "Refresh Zhihu cookies and scrape feeds via headless Chromium";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.nodejs_22 pkgs.xvfb-run ];
      environment = {
        PLAYWRIGHT_BROWSERS_PATH = "${playwright-browsers}";
        CHROMIUM_EXEC_PATH = chromiumPath;
        ENV_FILE = cfg.envFile;
      } // lib.optionalAttrs (cfg.feeds != []) {
        OUTPUT_DIR = cfg.outputDir;
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a ${pkgs.nodejs_22}/bin/node ${refreshScript}";
        TimeoutStartSec = if cfg.feeds != [] then "600" else "180";
      } // lib.optionalAttrs (cfg.restartService != null) {
        ExecStartPost = "+${pkgs.systemd}/bin/systemctl restart ${cfg.restartService}";
      };
    };

    systemd.timers.zhihu-cookie-refresh = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.initialDelay;
        Persistent = true;
        RandomizedDelaySec = "5min";
      } // (if cfg.onCalendar != null then {
        OnCalendar = cfg.onCalendar;
      } else {
        OnUnitActiveSec = cfg.interval;
      });
    };
  };
}
