'use strict';

const Module = require('node:module');
const original = Module._load;

const unavailable = new Proxy({}, {
  get(target, property) {
    if (property === 'then') return undefined;
    if (property === 'initializeSecurity' || property === 'isInitialized') return () => false;
    return () => { throw new Error(`security module unavailable (${String(property)})`); };
  },
});

Module._load = function (request, parent, isMain) {
  if (request === '@ali/pc-security-bodyguard') return unavailable;
  return original.call(this, request, parent, isMain);
};
