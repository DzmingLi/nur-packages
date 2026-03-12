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

    const fallbackSeedCookies = ${builtins.toJSON cfg.seedCookies};
    const envFile = process.env.ENV_FILE;
    const feedsConfig = ${builtins.toJSON cfg.feeds};
    const outputDir = process.env.OUTPUT_DIR || "";

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

    function launchChromium() {
      return new Promise((resolve, reject) => {
        const proc = spawn(process.env.CHROMIUM_EXEC_PATH, [
          '--remote-debugging-port=0',
          '--no-first-run',
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--proxy-server=direct://',
          '--window-size=1920,1080',
          '--lang=zh-CN',
          '--disable-blink-features=AutomationControlled',
          '--use-gl=angle',
          '--use-angle=swiftshader',
          '--enable-unsafe-swiftshader',
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

    // --- RSS XML helpers ---

    function escapeXml(s) {
      return String(s == null ? "" : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function toRssXml(feed) {
      let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
      xml += '<rss version="2.0">\n<channel>\n';
      xml += '<title>' + escapeXml(feed.title) + '</title>\n';
      xml += '<link>' + escapeXml(feed.link) + '</link>\n';
      xml += '<description>' + escapeXml(feed.description) + '</description>\n';
      xml += '<lastBuildDate>' + new Date().toUTCString() + '</lastBuildDate>\n';
      for (const item of feed.items) {
        xml += '<item>\n';
        xml += '<title>' + escapeXml(item.title) + '</title>\n';
        xml += '<link>' + escapeXml(item.link) + '</link>\n';
        if (item.guid) xml += '<guid isPermaLink="false">' + escapeXml(item.guid) + '</guid>\n';
        if (item.description) {
          const safe = item.description.replace(/]]>/g, ']]&gt;');
          xml += '<description><![CDATA[' + safe + ']]></description>\n';
        }
        if (item.pubDate) xml += '<pubDate>' + item.pubDate + '</pubDate>\n';
        if (item.author) xml += '<author>' + escapeXml(item.author) + '</author>\n';
        xml += '</item>\n';
      }
      xml += '</channel>\n</rss>\n';
      return xml;
    }

    // --- Page data extraction ---

    async function extractInitialData(page) {
      return page.evaluate(() => {
        const el = document.getElementById('js-initialData');
        if (!el) return null;
        try { return JSON.parse(el.textContent); } catch { return null; }
      });
    }

    async function scrapeHot(page) {
      console.log('Scraping /hot ...');
      await page.goto('https://www.zhihu.com/hot', {
        waitUntil: 'domcontentloaded', timeout: 30000,
      });
      if (page.url().includes('unhuman') || page.url().includes('signin')) {
        console.error('Redirected on /hot:', page.url());
        return null;
      }

      const data = await extractInitialData(page);
      if (!data) { console.error('No initialData on /hot'); return null; }

      const hotList = data.initialState && data.initialState.topstory
        && data.initialState.topstory.hotList;
      if (!hotList || !Array.isArray(hotList)) {
        console.error('No hotList in initialData');
        return null;
      }

      const items = hotList.map(item => {
        const t = item.target || {};
        const title = (t.titleArea && t.titleArea.text) || t.title || "";
        const excerpt = (t.excerptArea && t.excerptArea.text) || t.excerpt || "";
        // Extract question URL: link.url may be relative like "/question/12345"
        let link = (t.link && t.link.url) || "";
        if (link && !link.startsWith('http')) link = 'https://www.zhihu.com' + link;
        if (!link && t.id) link = 'https://www.zhihu.com/question/' + t.id;
        const metrics = (t.metricsArea && t.metricsArea.text) || "";
        const desc = excerpt + (metrics ? " (" + metrics + ")" : "");
        return { title, link, description: desc, guid: 'zhihu-hot-' + (t.id || "") };
      }).filter(i => i.title);

      console.log('Got ' + items.length + ' hot items');
      return {
        title: '知乎热榜',
        link: 'https://www.zhihu.com/hot',
        description: '知乎热榜',
        items,
      };
    }

    async function scrapePosts(page, usertype, userId) {
      const prefix = usertype === 'org' ? 'org' : 'people';
      console.log('Scraping /' + prefix + '/' + userId + '/posts ...');
      await page.goto('https://www.zhihu.com/' + prefix + '/' + userId + '/posts', {
        waitUntil: 'domcontentloaded', timeout: 30000,
      });

      if (page.url().includes('unhuman') || page.url().includes('signin')) {
        console.error('Redirected on /' + prefix + '/' + userId + ':', page.url());
        return null;
      }

      const data = await extractInitialData(page);
      if (!data) { console.error('No initialData on /' + prefix + '/' + userId); return null; }

      const entities = data.initialState && data.initialState.entities;
      const articles = entities && entities.articles;
      if (!articles || typeof articles !== 'object') {
        console.error('No articles for ' + userId);
        return null;
      }

      // Get user display name from entities.users
      const users = (entities && entities.users) || {};
      const userInfo = users[userId] || {};
      const userName = userInfo.name || userId;

      const items = Object.values(articles)
        .filter(a => a && a.title)
        .sort((a, b) => (b.created || 0) - (a.created || 0))
        .map(a => ({
          title: a.title,
          link: 'https://zhuanlan.zhihu.com/p/' + a.id,
          description: a.content || a.excerpt || "",
          pubDate: a.created ? new Date(a.created * 1000).toUTCString() : "",
          author: (a.author && a.author.name) || userName,
          guid: 'zhihu-article-' + a.id,
        }));

      console.log('Got ' + items.length + ' articles for ' + userName);
      return {
        title: userName + ' 的知乎文章',
        link: 'https://www.zhihu.com/' + prefix + '/' + userId + '/posts',
        description: userName + ' 在知乎发表的文章',
        items,
      };
    }

    // --- Main ---

    (async () => {
      const seedCookies = getSeedCookies();

      if (!seedCookies || !seedCookies.includes('z_c0=')) {
        console.log('No valid seed cookies (missing z_c0). Skipping.');
        process.exit(0);
      }

      console.log('Launching Chromium directly...');
      const { proc, wsEndpoint } = await launchChromium();
      console.log('Connected to Chromium via CDP');

      let browser;
      try {
        browser = await chromium.connectOverCDP(wsEndpoint);
        const context = browser.contexts()[0] || await browser.newContext();

        // Inject seed cookies
        const cookiePairs = seedCookies.split(';').map(s => s.trim()).filter(Boolean);
        const cookieObjects = cookiePairs.map(pair => {
          const idx = pair.indexOf('=');
          return {
            name: pair.substring(0, idx),
            value: pair.substring(idx + 1),
            domain: '.zhihu.com',
            path: '/',
          };
        });
        await context.addCookies(cookieObjects);

        const page = context.pages()[0] || await context.newPage();

        // Hide navigator.webdriver via CDP
        const cdp = await context.newCDPSession(page);
        await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
          source: 'Object.defineProperty(navigator, "webdriver", {get: () => false});',
        });

        page.on('console', msg => {
          if (msg.type() === 'error') console.log('PAGE ERROR:', msg.text());
        });
        page.on('pageerror', err => console.log('PAGE EXCEPTION:', err.message));

        // --- Cookie refresh ---
        await page.goto('https://www.zhihu.com/explore', {
          waitUntil: 'networkidle', timeout: 30000,
        });
        console.log('Page URL:', page.url());

        if (page.url().includes('unhuman')) {
          console.error('Anti-bot verification triggered');
          process.exit(2);
        }

        // Get __zse_ck: check page JS first
        let zseCk = null;
        const initCk = await page.evaluate(() =>
          document.cookie.match(/__zse_ck=([^;]+)/)?.[1]
        );
        if (initCk) {
          zseCk = initCk;
          console.log('Got __zse_ck from page JS');
        }

        // Inject v3.js if needed
        if (!zseCk) {
          console.log('__zse_ck not found, injecting v3.js...');
          await page.addScriptTag({ url: 'https://static.zhihu.com/zse-ck/v3.js' });
          try {
            await page.waitForFunction(
              "document.cookie.includes('__zse_ck')",
              { timeout: 15000 }
            );
            zseCk = await page.evaluate(() =>
              document.cookie.match(/__zse_ck=([^;]+)/)?.[1]
            );
            if (zseCk) console.log('Got __zse_ck after injecting v3.js');
          } catch {}
        }

        // Last resort: __g.ck global
        if (!zseCk) {
          try {
            zseCk = await page.evaluate(() =>
              typeof __g !== 'undefined' && __g.ck ? __g.ck : null
            );
            if (zseCk) console.log('Got __zse_ck from __g.ck');
          } catch {}
        }

        if (zseCk) {
          console.log('__zse_ck:', zseCk.substring(0, 20) + '...');
        } else {
          console.error('Failed to get __zse_ck');
          process.exit(1);
        }

        // Merge cookies: seed + browser + __zse_ck
        const seedMap = new Map();
        cookiePairs.forEach(pair => {
          const idx = pair.indexOf('=');
          if (idx > 0) seedMap.set(pair.substring(0, idx), pair.substring(idx + 1));
        });

        const browserCookies = await context.cookies('https://www.zhihu.com');
        browserCookies.forEach(c => seedMap.set(c.name, c.value));
        seedMap.set('__zse_ck', zseCk);

        if (!seedMap.has('z_c0')) {
          console.error('Merged cookies lost z_c0. Not overwriting env file.');
          process.exit(1);
        }

        const cookieStr = Array.from(seedMap.entries()).map(([k, v]) => k + '=' + v).join('; ');
        console.log('Merged', seedMap.size, 'cookies');

        writeFileSync(envFile,
          "ZHIHU_COOKIES='" + cookieStr.replace(/'/g, "'\\'''") + "'\n",
          { mode: 0o600 });

        console.log('Wrote', seedMap.size, 'cookies to env file');

        // --- Feed scraping (reuse same browser session) ---
        if (feedsConfig.length > 0 && outputDir) {
          console.log('Scraping ' + feedsConfig.length + ' feed(s)...');
          for (const feed of feedsConfig) {
            try {
              await new Promise(r => setTimeout(r, 2000));
              let result = null;
              if (feed.type === 'hot') {
                result = await scrapeHot(page);
              } else if (feed.type === 'posts') {
                result = await scrapePosts(page, feed.usertype || 'people', feed.id);
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
                console.error('No data for feed ' + feed.type + '/' + (feed.id || ""));
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
    })().catch(e => {
      console.error(e);
      process.exit(1);
    });
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
        After the first successful refresh, subsequent runs read cookies
        from the env file automatically.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/rsshub/zhihu-cookies.env";
      description = "Path to write the ZHIHU_COOKIES env file (shell-sourceable).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "rsshub";
      description = "User to run the service as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rsshub";
      description = "Group to run the service as.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "How often to refresh cookies and scrape feeds (systemd time span).";
    };

    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional OnCalendar schedule (overrides interval if set).";
    };

    initialDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      description = "Delay after boot before first run.";
    };

    restartService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "rsshub.service";
      description = "Service to restart after cookie refresh. Set to null to disable.";
    };

    feeds = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [ "hot" "posts" ];
            description = "Feed type: hot (trending) or posts (user articles).";
          };
          id = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "User ID (url_token) for posts feeds.";
          };
          usertype = lib.mkOption {
            type = lib.types.enum [ "people" "org" ];
            default = "people";
            description = "User type: people or org.";
          };
          output = lib.mkOption {
            type = lib.types.str;
            description = "Output path relative to outputDir (e.g. zhihu/hot).";
          };
        };
      });
      default = [];
      description = "Zhihu feeds to scrape via headless Chromium after cookie refresh.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/zhihu-feeds";
      description = "Directory to write scraped RSS XML files.";
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
