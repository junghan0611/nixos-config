// Run in the image; tests the actual emitted classifier without opening a DB.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const dist = process.argv[2] || '/app/dist';
const file = readdirSync(dist).filter(n => /^session-files-.*\.mjs$/.test(n))
	.find(n => readFileSync(`${dist}/${n}`, 'utf8').includes('function collectCronGeneratedSessionKeys(summaries) {'));
assert.ok(file);
const text = readFileSync(`${dist}/${file}`, 'utf8');
const keyFile = text.match(/import \{ b as isCronRunSessionKey[^}]*\} from "\.\/(session-key-[^"/]+\.mjs)";/)[1];
const { b: isCronRunSessionKey, x: isCronSessionKey } = await import(pathToFileURL(`${dist}/${keyFile}`));
const start = text.indexOf('function readParentSessionKeys(entry) {');
const end = text.indexOf('\nfunction toSessionStoreCorpusEntry(', start);
const collect = new Function('isCronRunSessionKey', 'isCronSessionKey',
	text.slice(start, end) + '\nreturn collectCronGeneratedSessionKeys;')(isCronRunSessionKey, isCronSessionKey);
const parent = 'agent:bbot:cron:job-1';
const run = `${parent}:run:run-1`;
const child = 'agent:bbot:subagent:child-1';
const orphan = 'agent:bbot:subagent:orphan-1';
const human = 'agent:bbot:telegram:bbot:direct:peer:cron:not-a-job';
const cases = [
	{sessionKey: parent, entry: {}},
	{sessionKey: run, entry: {}},
	{sessionKey: child, entry: {parentSessionKey: parent}},
	{sessionKey: orphan, entry: {spawnedBy: 'agent:bbot:cron:pruned-job'}},
	{sessionKey: human, entry: {}},
	{sessionKey: 'agent:bbot:main', entry: {}},
	{sessionKey: 'agent:bbot:subagent:a', entry: {spawnedBy: 'agent:bbot:subagent:b'}},
	{sessionKey: 'agent:bbot:subagent:b', entry: {spawnedBy: 'agent:bbot:subagent:a'}},
];
const keys = collect(cases);
const baseline = process.argv.includes('--baseline');
assert.equal(keys.has(parent), !baseline, 'cron parent admission');
assert.equal(keys.has(child), !baseline, 'child inherits cron parent');
assert.equal(keys.has(orphan), !baseline, 'pruned parent still identifies lineage');
assert.equal(keys.has(run), true, 'run remains excluded');
assert.equal(keys.has(human), false, 'human key containing cron is not a cron');
assert.equal(keys.has('agent:bbot:main'), false, 'main remains interactive');
assert.equal(keys.has('agent:bbot:subagent:a'), false, 'cycle is not cron');
assert.equal(keys.has('agent:bbot:subagent:b'), false, 'cycle terminates');
assert.equal(isCronSessionKey('not-agent:cron:job'), false, 'malformed key');
assert.equal(collect([...cases].reverse()).has(parent), !baseline, 'order independence');
console.log(`${baseline ? 'baseline reproduces parent omission' : 'patched parent admission'}: 10 assertions passed; no DB/API access`);
