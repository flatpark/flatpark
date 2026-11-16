'use strict'

// Linux account management is shipped as an unfinished fallback page. Keep the
// official login flow intact and only give that local page a usable shell.
if (process.platform === 'linux' && process.versions.electron) {
  const Module = require('module')
  const load = Module._load
  let installed = false

  Module._load = function (request, parent, isMain) {
    const electron = load.call(this, request, parent, isMain)
    if (request === 'electron' && !installed && process.type === 'browser') {
      installed = true
      install(electron.app)
    }
    return electron
  }

  function install(app) {
    app.on('browser-window-created', (_event, window) => {
      window.webContents.on('did-finish-load', () => {
        const url = window.webContents.getURL()
        const isAccountPage = url.endsWith('/pages/account/index.html')
        const isMainPage = url.endsWith('/pages/browserLikeWindow/index.html')
        if (!isAccountPage && !isMainPage) return

        if (isMainPage) {
          window.webContents.insertCSS(`
            .top-head-container,
            .control-container,
            .side-menu-container .side-content {
              -webkit-app-region: no-drag !important;
            }
            .top-head-container .btn,
            .control-container .btn,
            .side-menu-container .menu-item,
            .side-menu-container .version-button,
            .side-menu-container .checkbox-container,
            .top-head-container .right-action-user,
            .control-container .right-action-user {
              pointer-events: auto !important;
              -webkit-app-region: no-drag !important;
            }
          `)
          return
        }

        window.webContents.insertCSS(`
        :root {
          color-scheme: light dark;
          --account-bg: #ffffff;
          --account-surface: #ffffff;
          --account-text: rgba(0, 0, 0, .88);
          --account-muted: rgba(0, 0, 0, .52);
          --account-border: rgba(0, 0, 0, .08);
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --account-bg: #1f1f1f;
            --account-surface: #292929;
            --account-text: rgba(255, 255, 255, .92);
            --account-muted: rgba(255, 255, 255, .56);
            --account-border: rgba(255, 255, 255, .12);
          }
        }
        html, body, #app {
          width: 100%;
          min-width: 320px;
          min-height: 100%;
          margin: 0;
          background: var(--account-bg);
          color: var(--account-text);
        }
        body {
          font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        #app > div {
          box-sizing: border-box;
          width: min(100% - 32px, 720px) !important;
          height: auto !important;
          min-height: 240px;
          margin: 24px auto;
          padding: 20px;
          position: relative !important;
          left: auto !important;
          top: auto !important;
          transform: none !important;
          border: 1px solid var(--account-border);
          border-radius: 12px;
          background: var(--account-surface) !important;
          box-shadow: 0 8px 24px rgba(0, 0, 0, .12);
        }
        #app > div > div {
          box-sizing: border-box;
          min-height: 44px;
          display: flex;
          align-items: center;
          padding: 10px 12px;
          border-bottom: 1px solid var(--account-border);
          color: var(--account-text);
          cursor: pointer;
        }
        #app > div > div:hover {
          background: rgba(255, 80, 0, .08);
        }
        #app > div > div:last-child {
          margin-top: 12px;
          border: 0;
          color: #ff5000;
          justify-content: center;
        }
      `)
      })
    })
  }
}
