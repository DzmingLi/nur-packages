{ config, lib, pkgs, ... }:

let
  cfg = config.services.zhihu-cookie-refresh;

  playwright-browsers = pkgs.playwright-driver.passthru.browsers-chromium;
  chromiumRevision = pkgs.playwright-driver.passthru.browsersJSON.chromium.revision;
  chromiumPath = "${playwright-browsers}/chromium-${chromiumRevision}/chrome-linux64/chrome";

  refreshScript = pkgs.writeText "zhihu-cookie-refresh.js" ''
    const { chromium } = require('${pkgs.playwright-driver}');
    const { readFileSync, writeFileSync } = require('fs');
    const { spawn } = require('child_process');
    const { createInterface } = require('readline');

    const fallbackSeedCookies = ${builtins.toJSON cfg.seedCookies};
    const envFile = process.env.ENV_FILE;

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

    // Launch Chromium directly with WebGL support and no automation flags
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

    (async () => {
      const seedCookies = getSeedCookies();

      if (!seedCookies || !seedCookies.includes('z_c0=')) {
        console.log('No valid seed cookies (missing z_c0). Skipping refresh.');
        process.exit(0);
      }

      // Launch raw Chromium, then connect via CDP (no automation signals)
      console.log('Launching Chromium directly...');
      const { proc, wsEndpoint } = await launchChromium();
      console.log('Connected to Chromium via CDP');

      let browser;
      try {
        browser = await chromium.connectOverCDP(wsEndpoint);
        const context = browser.contexts()[0] || await browser.newContext();

        // Inject seed cookies via CDP
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

        // Hide navigator.webdriver via CDP (set before page load)
        const cdp = await context.newCDPSession(page);
        await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
          source: 'Object.defineProperty(navigator, "webdriver", {get: () => false});',
        });

        // Capture console errors
        page.on('console', msg => {
          if (msg.type() === 'error') console.log('PAGE ERROR:', msg.text());
        });
        page.on('pageerror', err => console.log('PAGE EXCEPTION:', err.message));

        await page.goto('https://www.zhihu.com/explore', {
          waitUntil: 'networkidle', timeout: 30000,
        });
        console.log('Page URL:', page.url());

        if (page.url().includes('unhuman')) {
          console.error('Anti-bot verification triggered');
          process.exit(2);
        }

        // Diagnose: check if v3.js loaded and __g global exists
        const diag = await page.evaluate(() => ({
          hasG: typeof __g !== 'undefined',
          gKeys: typeof __g !== 'undefined' ? Object.keys(__g).join(',') : 'N/A',
          gCk: typeof __g !== 'undefined' ? __g.ck : 'N/A',
          docCookieHasZseCk: document.cookie.includes('__zse_ck'),
          webdriver: navigator.webdriver,
          webglRenderer: (() => {
            try {
              const c = document.createElement('canvas');
              const gl = c.getContext('webgl');
              const ext = gl.getExtension('WEBGL_debug_renderer_info');
              return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'no ext';
            } catch(e) { return 'error: ' + e.message; }
          })(),
        }));
        console.log('Diagnostics:', JSON.stringify(diag));

        // Wait for __zse_ck
        let zseCk = null;

        // Method 1: check __g.ck directly
        if (diag.gCk && diag.gCk !== 'N/A' && typeof diag.gCk === 'string' && diag.gCk.length > 5) {
          zseCk = diag.gCk;
          console.log('Got __zse_ck from __g.ck');
        }

        // Method 2: wait for document.cookie
        if (!zseCk) {
          try {
            await page.waitForFunction(
              "document.cookie.includes('__zse_ck')",
              { timeout: 15000 }
            );
            const m = await page.evaluate(() =>
              document.cookie.match(/__zse_ck=([^;]+)/)?.[1]
            );
            if (m) { zseCk = m; console.log('Got __zse_ck from document.cookie'); }
          } catch {}
        }

        if (zseCk) {
          console.log('__zse_ck:', zseCk.substring(0, 20) + '...');
        } else {
          console.error('Failed to get __zse_ck');
          process.exit(1);
        }

        // Merge: seed cookies + browser cookies + __zse_ck
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
    enable = lib.mkEnableOption "Zhihu cookie refresh via headless Chromium";

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
      description = "User to run the refresh service as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rsshub";
      description = "Group to run the refresh service as.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "How often to refresh cookies (systemd time span).";
    };

    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional OnCalendar schedule (overrides interval if set).";
    };

    initialDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      description = "Delay after boot before first refresh.";
    };

    restartService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "rsshub.service";
      description = "Service to restart after cookie refresh. Set to null to disable.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "f ${cfg.envFile} 0600 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.zhihu-cookie-refresh = {
      description = "Refresh Zhihu cookies via headless Chromium";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.nodejs_22 pkgs.xvfb-run ];
      environment = {
        PLAYWRIGHT_BROWSERS_PATH = "${playwright-browsers}";
        CHROMIUM_EXEC_PATH = chromiumPath;
        ENV_FILE = cfg.envFile;
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a ${pkgs.nodejs_22}/bin/node ${refreshScript}";
        TimeoutStartSec = "180";
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
