// Actual 11.3 emitted classifier copies (main chunk + two worker bundles), including upstream cycle propagation.
// No database, Gateway, credentials, network or model access.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const dist = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : '/app/dist';
const baseline = process.argv.includes('--baseline');
const SIG = 'function collectCronGeneratedSessionKeys(';
const PARENT_SIG = 'function readParentSessionKeys(';
const count = (text, needle) => text.split(needle).length - 1;

function braceBlock(text, sig) {
	assert.equal(count(text, sig), 1, `unique ${sig}`);
	const start = text.indexOf(sig);
	let depth = 0;
	for (let i = text.indexOf('{', start); i < text.length; i++) {
		if (text[i] === '{') depth++;
		else if (text[i] === '}' && --depth === 0) return text.slice(start, i + 1);
	}
	throw new Error(`unterminated ${sig}`);
}

// Locator: every emitted definition in dist must be covered. 11.3 emits three copies.
const copies = readdirSync(dist, { recursive: true })
	.filter(n => /\.(mjs|js)$/.test(n))
	.filter(n => readFileSync(path.join(dist, n), 'utf8').includes(SIG))
	.sort();
assert.equal(copies.length, 3, `three emitted classifier copies (found: ${copies.join(', ')})`);
const kinds = copies.map(n => n === path.join('worker', 'sqlite-store.worker.mjs') ? 'bundle'
	: n.startsWith(`worker${path.sep}worker-chunk-`) ? 'worker-chunk' : !n.includes(path.sep) ? 'main' : 'unknown');
assert.deepEqual([...kinds].sort(), ['bundle', 'main', 'worker-chunk'], 'one main, one store bundle, one worker chunk');

async function importedBinding(text, file, name) {
	for (const m of text.matchAll(/import\s*\{([^}]*)\}\s*from\s*"\.\/([^"]+)";/g)) {
		const spec = m[1].split(',').map(s => s.trim().split(/\s+as\s+/));
		const hit = spec.find(([, local]) => local === name);
		if (hit) return (await import(pathToFileURL(path.join(path.dirname(file), m[2]))))[hit[0]];
	}
	return undefined;
}

// Lexical-scope proof: resolve an identifier at a source offset to its declaring node with the image's own
// acorn, walking the real enclosing scopes. new Function() injection below cannot see a missing binding.
const acorn = createRequire(path.join(dist, '..', 'package.json'))('acorn');
const isNode = v => v && typeof v === 'object' && typeof v.type === 'string';
const children = n => Object.keys(n).flatMap(k => (Array.isArray(n[k]) ? n[k] : [n[k]]).filter(isNode));
const isFn = n => /^(FunctionDeclaration|FunctionExpression|ArrowFunctionExpression)$/.test(n.type);
function patternNames(p, out = []) {
	if (!p) return out;
	if (p.type === 'Identifier') out.push([p.name, p]);
	else if (p.type === 'ObjectPattern') for (const q of p.properties) patternNames(q.type === 'RestElement' ? q.argument : q.value, out);
	else if (p.type === 'ArrayPattern') for (const q of p.elements) patternNames(q, out);
	else if (p.type === 'RestElement') patternNames(p.argument, out);
	else if (p.type === 'AssignmentPattern') patternNames(p.left, out);
	return out;
}
function hoistedVars(node, out) {
	for (const c of children(node)) {
		if (isFn(c)) continue;
		if (c.type === 'VariableDeclaration' && c.kind === 'var') for (const d of c.declarations) for (const [n] of patternNames(d.id)) out.set(n, c);
		hoistedVars(c, out);
	}
	return out;
}
function lexical(statements, out) {
	for (const s0 of statements) {
		const s = (s0.type === 'ExportNamedDeclaration' || s0.type === 'ExportDefaultDeclaration') && s0.declaration ? s0.declaration : s0;
		if (s.type === 'VariableDeclaration' && s.kind !== 'var') for (const d of s.declarations) for (const [n] of patternNames(d.id)) out.set(n, s);
		else if ((s.type === 'FunctionDeclaration' || s.type === 'ClassDeclaration') && s.id) out.set(s.id.name, s);
		else if (s.type === 'ImportDeclaration') for (const sp of s.specifiers) out.set(sp.local.name, sp);
	}
	return out;
}
function declsOf(n) {
	const m = new Map();
	if (isFn(n)) {
		for (const p of n.params) for (const [name] of patternNames(p)) m.set(name, p);
		if (n.type === 'FunctionExpression' && n.id) m.set(n.id.name, n);
		hoistedVars(n.body, m);
	} else if (n.type === 'Program') { hoistedVars(n, m); lexical(n.body, m); }
	else if (n.type === 'BlockStatement' || n.type === 'StaticBlock') lexical(n.body, m);
	else if (n.type === 'SwitchStatement') lexical(n.cases.flatMap(c => c.consequent), m);
	else if (/^For(In|Of)?Statement$/.test(n.type)) { const d = n.init ?? n.left; if (d?.type === 'VariableDeclaration' && d.kind !== 'var') lexical([d], m); }
	else if (n.type === 'CatchClause') for (const [name] of patternNames(n.param)) m.set(name, n);
	return m;
}
function resolveAt(ast, pos, name) {
	const chain = [ast];
	for (let n = ast; ;) {
		const next = children(n).find(c => c.start <= pos && pos < c.end);
		if (!next) break;
		chain.push(n = next);
	}
	const id = chain.at(-1);
	assert.ok(id.type === 'Identifier' && id.name === name, `identifier ${name} at offset ${pos}`);
	for (let i = chain.length - 1; i >= 0; i--) {
		const d = declsOf(chain[i]).get(name);
		if (d) return { decl: d, scope: chain[i], depth: chain.filter(isFn).length };
	}
	return undefined;
}
function scopeProof(kind, file, text, cls) {
	const ast = acorn.parse(text, { ecmaVersion: 'latest', sourceType: 'module' });
	const callPos = text.indexOf(`${cls}(`, text.indexOf(SIG));
	const hit = resolveAt(ast, callPos, cls);
	assert.ok(hit, `${kind}: ${cls} has a lexical binding at the classifier call (no ReferenceError)`);
	const { decl, scope } = hit;
	const names = ['isCronRunSessionKey', 'isCronSessionKey'];
	if (decl.type === 'ImportSpecifier') {
		const source = ast.body.find(s => s.type === 'ImportDeclaration' && s.specifiers.includes(decl)).source.value;
		const helperText = readFileSync(path.join(path.dirname(file), source), 'utf8');
		const exported = decl.imported.name;
		const helper = names.find(h => helperText.includes(`${h} as ${exported},`) || helperText.includes(`${h} as ${exported} `) || helperText.includes(`${h} as ${exported}}`));
		assert.ok(helper, `${kind}: ${cls} imports ${source} export ${exported} = cron classifier`);
		return { helper, line: `${kind}: ${cls} -> import { ${exported} } from "${source}" = ${helper}, scope=${scope.type}` };
	}
	assert.equal(decl.type, 'FunctionDeclaration', `${kind}: ${cls} binds a function declaration`);
	const helper = decl.id.name;
	assert.ok(names.includes(helper), `${kind}: ${cls} binds ${helper}`);
	const def = text.slice(decl.start, decl.end);
	assert.ok((helper === 'isCronRunSessionKey' ? RUN_DEF : CRON_DEF).test(def), `${kind}: ${helper} definition shape`);
	// The helper's own free identifiers must resolve too, from inside its body.
	for (const dep of ['parseAgentSessionKey', ...(helper === 'isCronSessionKey' ? ['normalizeOptionalLowercaseString'] : [])])
		assert.ok(resolveAt(ast, decl.start + def.indexOf(`${dep}(`), dep), `${kind}: ${helper} dependency ${dep} resolves`);
	return { helper, line: `${kind}: ${cls} -> function ${helper} @${decl.start} (${def.length}B), scope=${scope.type}; deps resolve` };
}
const scopeLines = [];

const RUN_DEF =/^function isCronRunSessionKey\((\w+)\)\{let (\w+)=parseAgentSessionKey\(\1\);return \2\?\/\^cron:\[\^:\]\+:run:\[\^:\]\+\(\?::\|\$\)\/\.test\(\2\.rest\):!1\}$/;
const CRON_DEF = /^function isCronSessionKey\((\w+)\)\{let (\w+)=parseAgentSessionKey\(\1\);return \2\?normalizeOptionalLowercaseString\(\2\.rest\)\?\.startsWith\(`cron:`\)===!0:!1\}$/;
let mainHelpers;

async function load(name, kind) {
	const file = path.join(dist, name);
	const text = readFileSync(file, 'utf8');
	const collectBlock = braceBlock(text, SIG);
	const parentBlock = braceBlock(text, PARENT_SIG);
	const cls = collectBlock.match(/isCronGenerated\s*=\s*\([^)]*\)\s*=>\s*\{\s*if\s*\(\s*([A-Za-z_$][\w$]*)\(/)?.[1];
	assert.ok(cls, `${kind}: classifier call located`);
	assert.equal(count(collectBlock, `${cls}(`), 1, `${kind}: single classifier call`);
	let fn;
	if (kind === 'bundle') {
		// In-bundle helper: verify emitted definition text, then bind the same-named main helper.
		const def = braceBlock(text, `function ${cls}(`);
		assert.ok((cls === 'isCronRunSessionKey' ? RUN_DEF : CRON_DEF).test(def), `${kind}: ${cls} definition shape`);
		fn = mainHelpers[cls];
	} else if (kind === 'worker-chunk') {
		// Lazy-init worker helper module: verify the bound export's real name and emitted shape,
		// then bind the same-named main helper (importing it alone leaves its module state uninitialized).
		const bound = await importedBinding(text, file, cls);
		assert.equal(typeof bound, 'function', `${kind}: ${cls} import binding`);
		assert.ok(['isCronRunSessionKey', 'isCronSessionKey'].includes(bound.name), `${kind}: ${cls} binds ${bound.name}`);
		const src = bound.toString();
		assert.ok(bound.name === 'isCronRunSessionKey' ? src.includes('/^cron:[^:]+:run:[^:]+(?::|$)/.test(') : src.includes('?.startsWith(`cron:`)===!0'), `${kind}: ${bound.name} emitted shape`);
		fn = mainHelpers[bound.name];
	} else {
		fn = await importedBinding(text, file, cls);
	}
	assert.equal(typeof fn, 'function', `${kind}: ${cls} resolves to a function`);
	if (kind === 'main') {
		mainHelpers = {
			isCronRunSessionKey: cls === 'isCronRunSessionKey' ? fn : await importedBinding(text, file, 'isCronRunSessionKey'),
			isCronSessionKey: cls === 'isCronSessionKey' ? fn : undefined,
		};
		if (!mainHelpers.isCronSessionKey) {
			// Unpatched main chunk does not import it; read it from the same helper module.
			const m = text.match(/import\s*\{[^}]*\bas isCronRunSessionKey\b[^}]*\}\s*from\s*"\.\/([^"]+)";/);
			const mod = await import(pathToFileURL(path.join(dist, m[1])));
			const helperText = readFileSync(path.join(dist, m[1]), 'utf8');
			const letter = helperText.match(/isCronSessionKey as (\w+)/)[1];
			mainHelpers.isCronSessionKey = mod[letter];
		}
	}
	const proof = scopeProof(kind, file, text, cls);
	assert.equal(proof.helper, fn.name, `${kind}: lexical binding and behaviour binding agree (${proof.helper})`);
	scopeLines.push(proof.line);
	let collect = new Function(cls, `${parentBlock}\n${collectBlock}\nreturn collectCronGeneratedSessionKeys;`)(fn);
	if (kind === 'main') {
		// Real execution in the emitted module's own scope: the chunk exports the actual function.
		const mod = await import(pathToFileURL(file));
		const real = Object.values(mod).find(v => typeof v === 'function' && v.name === 'collectCronGeneratedSessionKeys');
		assert.ok(real, 'main: emitted module exports collectCronGeneratedSessionKeys');
		assert.equal(real.toString(), collectBlock, 'main: exported function is the located block');
		collect = real;
		scopeLines.push('main: behaviour assertions run on the imported module export (real lexical scope)');
	}
	return { kind, name, cls, fn, collect };
}

const order = ['main', 'bundle', 'worker-chunk'];
const loaded = [];
for (const k of order) loaded.push(await load(copies[kinds.indexOf(k)], k));

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
for (const { kind, fn, collect } of loaded) {
	const keys = collect(cases);
	assert.equal(keys.has(parent), !baseline, `${kind}: cron parent admission`);
	assert.equal(keys.has(child), !baseline, `${kind}: child inherits cron parent`);
	assert.equal(keys.has(orphan), !baseline, `${kind}: pruned parent still identifies lineage`);
	assert.equal(keys.has(run), true, `${kind}: run remains excluded`);
	assert.equal(keys.has(human), false, `${kind}: human key containing cron is not a cron`);
	assert.equal(keys.has('agent:bbot:main'), false, `${kind}: main remains interactive`);
	assert.equal(keys.has('agent:bbot:subagent:a'), false, `${kind}: cycle is not cron`);
	assert.equal(keys.has('agent:bbot:subagent:b'), false, `${kind}: cycle terminates`);
	assert.equal(fn('not-agent:cron:job'), false, `${kind}: malformed key`);
	assert.equal(collect([...cases].reverse()).has(parent), !baseline, `${kind}: order independence`);
	const cycleA = 'agent:bbot:subagent:cycle-a';
	const cycleB = 'agent:bbot:subagent:cycle-b';
	const cyclic = collect([
		{sessionKey: cycleA, entry: {parentSessionKey: cycleB, spawnedBy: run}},
		{sessionKey: cycleB, entry: {parentSessionKey: cycleA}},
		{sessionKey: run, entry: {}},
	]);
	assert.equal(cyclic.has(cycleA), true, `${kind}: upstream observed-edge cycle propagation A preserved`);
	assert.equal(cyclic.has(cycleB), true, `${kind}: upstream observed-edge cycle propagation B preserved`);
}
// Port-coverage contract: every copy must agree (a partial port of only one locator is RED).
const verdicts = loaded.map(({ collect }) => collect(cases).has(parent));
assert.ok(verdicts.every(v => v === !baseline), `all copies agree on cron parent admission (${verdicts.join(',')})`);
for (const l of scopeLines) console.log(`scope proof: ${l}`);
console.log(`${baseline ? 'baseline reproduces parent omission' : 'patched parent admission'}: 12 behavior assertions passed x ${loaded.length} copies (${loaded.map(l => `${l.kind}=${l.name}`).join(' ')}) + locator/coverage assertions; no DB/API access`);
