#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Exercise the real wrapper with an isolated AppDir and command recorder.
# No vendor binary or installed Flatpak is executed by this contract test.
node --input-type=module - "$ROOT" <<'JS'
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
const root=process.argv[2], temp=fs.mkdtempSync(path.join(os.tmpdir(),'flatpark-blanc-'));
try {
  const app=path.join(temp,'blanc'),bin=path.join(temp,'bin'),config=path.join(temp,'config');
  fs.mkdirSync(app);fs.mkdirSync(bin);fs.mkdirSync(config);
  const quote=s=>"'"+s.replaceAll("'","'\\''")+"'";
  const wrapper=path.join(temp,'wrapper');
  fs.writeFileSync(wrapper,fs.readFileSync(path.join(root,'registry/com.blancbrowser.Blanc/blanc-wrapper'),'utf8').replace('app_dir=/app/extra/blanc',`app_dir=${quote(app)}`),{mode:0o755});
  fs.writeFileSync(path.join(app,'blanc-ecs-launcher'),'#!/bin/sh\n[ "$#" = 1 ] && [ "$1" = --ecs-query-cdm ] || exit 97\nprintf query >> "$QUERY_LOG"\n[ "${QUERY_EXIT:-0}" = 0 ] || exit "$QUERY_EXIT"\nprintf "%s\\n" "${QUERY_RESULT:-}"\n',{mode:0o755});
  fs.writeFileSync(path.join(bin,'zypak-wrapper'),'#!/usr/bin/env node\nconsole.log(JSON.stringify({args:process.argv.slice(2),env:Object.fromEntries(["BLANC_UPDATE_CHANNEL","BLANC_ECS_LAUNCHER_ROOT","BLANC_ECS_FULL_PROFILE","ZYPAK_LD_PRELOAD","BLANC_ECS_CDM_PRELOAD_PATH","BLANC_ECS_CDM_EXECUTABLE","ELECTRON_RUN_AS_NODE","ELECTRON_NO_ATTACH_CONSOLE"].map(k=>[k,process.env[k]??null]))}));\n',{mode:0o755});
  const env={...process.env,PATH:bin+path.delimiter+process.env.PATH,XDG_CONFIG_HOME:config,QUERY_LOG:path.join(temp,'query.log'),QUERY_RESULT:'/cached/libwidevinecdm.so',ELECTRON_RUN_AS_NODE:'1',ELECTRON_NO_ATTACH_CONSOLE:'1',ZYPAK_LD_PRELOAD:'/untrusted.so',BLANC_ECS_CDM_PRELOAD_PATH:'/stale.so',BLANC_ECS_CDM_EXECUTABLE:'/stale/blanc'};
  const run=(args=[],overrides={})=>spawnSync(wrapper,args,{env:{...env,...overrides},encoding:'utf8'});
  fs.writeFileSync(path.join(temp,'launcher'),'blanc-ecs-launcher\n');
  let result=run(['https://example.com']);assert.equal(result.status,0,result.stderr);
  const record=JSON.parse(result.stdout);
  assert.deepEqual(record.args,[path.join(app,'blanc'),`--user-data-dir=${config}/Blanc`,'--ozone-platform-hint=auto','https://example.com']);
  assert.equal(record.env.BLANC_UPDATE_CHANNEL,'flatpak');
  assert.equal(record.env.BLANC_ECS_LAUNCHER_ROOT,app);
  assert.equal(record.env.BLANC_ECS_FULL_PROFILE,path.join(config,'Blanc'));
  for(const k of ['ZYPAK_LD_PRELOAD','BLANC_ECS_CDM_PRELOAD_PATH','BLANC_ECS_CDM_EXECUTABLE','ELECTRON_RUN_AS_NODE','ELECTRON_NO_ATTACH_CONSOLE'])assert.equal(record.env[k],null,k);
  assert.match(result.stderr,/protected playback remains unavailable/);
  assert.equal(fs.statSync(path.join(config,'Blanc')).mode&0o777,0o700);
  assert.equal(fs.readFileSync(env.QUERY_LOG,'utf8'),'query');
  fs.unlinkSync(env.QUERY_LOG);
  for(const args of [['--user-data-dir=/tmp/other'],['--user-data-dir','/tmp/other']]) {
    result=run(args);assert.notEqual(result.status,0);assert.equal(result.stdout,'');assert.equal(fs.existsSync(env.QUERY_LOG),false);
  }
  result=run([],{XDG_CONFIG_HOME:'relative'});assert.notEqual(result.status,0);assert.equal(result.stdout,'');
  result=run([],{QUERY_EXIT:'42'});assert.equal(result.status,42);assert.equal(result.stdout,'');
  fs.writeFileSync(path.join(temp,'launcher'),'blanc\n');
  result=run(['https://example.com']);assert.equal(result.status,0,result.stderr);
  assert.deepEqual(JSON.parse(result.stdout).args,[path.join(app,'blanc'),'--ozone-platform-hint=auto','https://example.com']);
  console.log('test_blanc_wrapper: PASS');
} finally { fs.rmSync(temp,{recursive:true,force:true}); }
JS
