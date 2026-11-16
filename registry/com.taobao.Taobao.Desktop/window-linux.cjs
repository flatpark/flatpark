'use strict'

// The client draws its own title-bar controls. On Linux, keep those controls
// and remove the native frame that Electron otherwise adds around the window.
if (process.platform === 'linux' && process.versions.electron && process.type === 'browser') {
  const Module = require('module')
  const load = Module._load
  let wrappedBrowserWindow

  Module._load = function (request, parent, isMain) {
    const electron = load.call(this, request, parent, isMain)
    if (request !== 'electron' || typeof electron.BrowserWindow !== 'function') return electron

    if (!wrappedBrowserWindow) wrappedBrowserWindow = wrapBrowserWindow(electron.BrowserWindow)
    return new Proxy(electron, {
      get(target, property, receiver) {
        return property === 'BrowserWindow'
          ? wrappedBrowserWindow
          : Reflect.get(target, property, receiver)
      }
    })
  }
}

function wrapBrowserWindow(BrowserWindow) {
  return new Proxy(BrowserWindow, {
    construct(target, args, newTarget) {
      const options = args[0]
      if (options && Object.prototype.hasOwnProperty.call(options, 'titleBarStyle')) {
        args[0] = { ...options, frame: false, hasShadow: false, titleBarOverlay: false }
      }
      return Reflect.construct(target, args, newTarget)
    }
  })
}
