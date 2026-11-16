'use strict'

// Linux 托盘修补：官方客户端按 macOS 菜单栏的方式做托盘，Linux 上图标和菜单都不对。
// 1. 图标：非 Windows 分支用 taobaoTemplate.png（16x16 白色模板图，为 macOS 深色菜单栏准备），
//    在 Linux 面板上等于看不见 —— 换成应用自己的彩色图标。
// 2. 菜单：菜单只在 popUpContextMenu 里弹出，而这个 API 是 macOS/Windows 专属，
//    right-click 事件在 Linux 也不发；StatusNotifierItem 靠 setContextMenu 才能导出菜单。

if (process.platform === 'linux' && process.versions.electron && process.type === 'browser') {
  const Module = require('module')
  const load = Module._load
  let initialized = false
  Module._load = function (request, parent, isMain) {
    const exports = load.call(this, request, parent, isMain)
    if (request === 'electron' && !initialized) {
      initialized = true
      patchTray(exports)
    }
    return exports
  }
}

function patchTray({ Tray, nativeImage }) {

  const icon = nativeImage
    .createFromPath('/app/share/icons/hicolor/256x256/apps/com.taobao.Taobao.Desktop.png')
    .resize({ width: 32, height: 32 })

  if (!icon.isEmpty()) {
    const createFromPath = nativeImage.createFromPath
    nativeImage.createFromPath = function (filePath, scaleFactor) {
      return /taobaoTemplate(@2x)?\.png$/i.test(String(filePath))
        ? icon
        : createFromPath.call(this, filePath, scaleFactor)
    }
  }

  Tray.prototype.popUpContextMenu = function (menu) {
    if (menu) this.setContextMenu(menu)
  }

  // 客户端只在点击后才组装菜单，先替用户点一下，让菜单在托盘出现时就绪。
  const setToolTip = Tray.prototype.setToolTip
  Tray.prototype.setToolTip = function (toolTip) {
    const result = setToolTip.call(this, toolTip)
    if (!this.__menuPrimed) {
      this.__menuPrimed = true
      setTimeout(() => this.emit('click'), 0)
    }
    return result
  }
}
