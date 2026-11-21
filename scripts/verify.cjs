const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), vm = require('node:vm'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..'), read = p => fs.readFileSync(path.join(root,p),'utf8');
const model = read('harmony/entry/src/main/ets/model/Models.ets');
const functions = model.slice(model.indexOf('export function boundedSeek')).replace(/export /g,'').replace(/: (number|boolean|Segment)\b/g,'');
const context = {}; vm.createContext(context); vm.runInContext(functions,context);
for (const [value,duration,expected] of [[-5,30,0],[35,30,30],[10,30,10],[35,0,35],[NaN,30,0],[Infinity,30,0],[35,Infinity,35]]) assert.equal(context.boundedSeek(value,duration),expected);
for (const [a,b,valid] of [[0,1,true],[1,1,false],[-1,2,false],[2,1,false],[NaN,2,false],[1,Infinity,false],[0.5,0.6,true]]) assert.equal(context.validSegment({APos:a,BPos:b}),valid);
assert.equal(context.toggleActive(-1,0,2),0); assert.equal(context.toggleActive(0,0,2),-1); assert.equal(context.toggleActive(0,1,2),1); assert.equal(context.toggleActive(0,3,2),0);
assert.equal(context.activeAfterDelete(2,0),1); assert.equal(context.activeAfterDelete(1,1),-1); assert.equal(context.activeAfterDelete(0,1),0);
for (const vector of JSON.parse(read('reference/aes-vectors.json'))) {
  const input = Buffer.from(vector.plain), padded = Buffer.alloc((Math.floor(input.length/16)+1)*16); input.copy(padded);
  const key = Buffer.from('gww417038_x8888x'), cipher = crypto.createCipheriv('aes-128-cbc',key,key); cipher.setAutoPadding(false);
  assert.equal(Buffer.concat([cipher.update(padded),cipher.final()]).toString('base64'),vector.base64);
}
const swiftSession = read('ios/RedFoxListen/Session.swift'), arkApi = read('harmony/entry/src/main/ets/model/Api.ets');
assert(swiftSession.includes('input += Array(repeating: 0, count: 16 - input.count % 16)'));
assert(arkApi.includes('(Math.floor(bytes.length / 16) + 1) * 16'));
assert(swiftSession.includes('http://47.97.107.100:8090/')); assert(arkApi.includes('http://47.97.107.100:8090/'));
const allSwift = ['Session','AuthView','RootView','Playback'].map(x=>read('ios/RedFoxListen/'+x+'.swift')).join('\n');
const arkUI = read('harmony/entry/src/main/ets/pages/Index.ets');
const endpoints = [...read('reference/ApiService.kt').matchAll(/@POST\("([^"]+)"\)/g)].map(x=>x[1]);
for (const endpoint of endpoints) { assert(allSwift.includes(endpoint),'Missing Swift endpoint '+endpoint); assert(arkUI.includes(endpoint),'Missing ArkUI endpoint '+endpoint); }
const project = read('ios/RedFoxListen.xcodeproj/project.pbxproj');
const declared = new Set([...project.matchAll(/^([A-F0-9]{24}) = /gm)].map(m=>m[1]));
for (const ref of project.match(/\b[A-F0-9]{24}\b/g)) assert(declared.has(ref),'Dangling Xcode ref '+ref);
const sourcePhase = project.match(/isa = PBXSourcesBuildPhase;[^\n]+/)[0];
for (const m of project.matchAll(/([A-F0-9]{24}) = \{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ([^;]+);/g)) {
  assert(fs.existsSync(path.join(root,'ios/RedFoxListen',m[2])),'Missing source '+m[2]);
  const build = [...project.matchAll(/([A-F0-9]{24}) = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24});/g)].find(x=>x[2]===m[1]);
  assert(build && sourcePhase.includes(build[1]),'Swift file not compiled: '+m[2]);
}
function walk(dir) { return fs.readdirSync(dir,{withFileTypes:true}).filter(e=>!['.hvigor','build','.idea','oh_modules'].includes(e.name)).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]); }
let configs = 0;
for (const file of walk(root)) {
  if (/\.(json|json5)$/.test(file)) { JSON.parse(fs.readFileSync(file,'utf8')); configs++; }
  if (/\.(swift|ets|json5|yml)$/.test(file)) { const text = fs.readFileSync(file,'utf8'); assert(!text.includes('???'),'Damaged encoding: '+file); }
}
const config = JSON.parse(read('harmony/build-profile.json5')); assert(!config.app.signingConfigs,'Do not inherit another app signing material');
const pages = JSON.parse(read('harmony/entry/src/main/resources/base/profile/main_pages.json')).src;
for (const page of pages) assert(fs.existsSync(path.join(root,'harmony/entry/src/main/ets',page+'.ets')));
console.log('PASS: 21 AB/seek boundary cases; 6 actual BouncyCastle AES fixtures; '+endpoints.length+' endpoint mappings on both platforms; Xcode source phases; '+configs+' JSON files; UTF-8; Harmony entry and signing isolation.');
console.log('This check does not replace iOS compilation, device playback or live backend integration.');
