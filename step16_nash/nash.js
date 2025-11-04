#!/usr/bin/env node
/* nash.js — 2x2 Nash checks (pure/mixed) + PoA (utility|cost) + JSON output */
const fs = require('fs');

function parseArgs(argv){
  const args = { json:false, poa:'util', file:null };
  const rest = [];
  for(const a of argv.slice(2)){
    if(a==='--json') args.json = true;
    else if(a==='--poa'){ /* expects next */ }
    else if(a.startsWith('--poa=')){ args.poa = a.split('=')[1]; }
    else if(a==='--poa' || a==='--cost'){ args.poa = 'cost'; }
    else if(a==='--util'){ args.poa = 'util'; }
    else if(a.startsWith('-')) { /* ignore unknown flag */ }
    else { rest.push(a); }
  }
  if (rest.length>0) args.file = rest[0];
  return args;
}

function parseGame(text){
  const lines = text.split(/\r?\n/).map(l => l.replace(/#.*$/, '').trim()).filter(Boolean);
  let players = null, Aname = null, Bname = null;
  let Astr = null, Bstr = null;
  const pay = {};
  let inPay = false, m;

  for (const line of lines){
    if ((m = line.match(/^players\s*:\s*([^,]+)\s*,\s*([^,]+)\s*$/i))){
      Aname = m[1].trim(); Bname = m[2].trim(); players = [Aname, Bname]; continue;
    }
    if ((m = line.match(/^(\S+)\s*:\s*([^,]+)\s*,\s*([^,]+)\s*$/)) && players && (m[1]===Aname || m[1]===Bname)){
      if (m[1] === Aname) Astr = [m[2].trim(), m[3].trim()];
      else Bstr = [m[2].trim(), m[3].trim()];
      continue;
    }
    if (/^payoffs\s*:\s*$/i.test(line)){ inPay = true; continue; }
    if (inPay && (m = line.match(/^([^,]+)\s*,\s*([^:]+)\s*:\s*\(\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\)\s*$/))){
      const sa = m[1].trim(), sb = m[2].trim();
      const ua = Number(m[3]), ub = Number(m[4]);
      if (Number.isNaN(ua) || Number.isNaN(ub)) throw new Error('Non-numeric payoff');
      pay[`${sa}|${sb}`] = [ua, ub];
      continue;
    }
    throw new Error(`Unrecognized line: ${line}`);
  }

  if (!players || !Astr || !Bstr) throw new Error('Incomplete header');
  const need = [[Astr[0],Bstr[0]],[Astr[0],Bstr[1]],[Astr[1],Bstr[0]],[Astr[1],Bstr[1]]];
  for (const [sa,sb] of need) if (!( `${sa}|${sb}` in pay)) throw new Error(`Missing payoff for ${sa},${sb}`);

  const U = [
    [ pay[`${Astr[0]}|${Bstr[0]}`], pay[`${Astr[0]}|${Bstr[1]}`] ],
    [ pay[`${Astr[1]}|${Bstr[0]}`], pay[`${Astr[1]}|${Bstr[1]}`] ]
  ];
  return { players, Astr, Bstr, U };
}

function pureNE(game){
  const {U} = game; const res=[];
  for(let i=0;i<2;i++) for(let j=0;j<2;j++){
    const ua=U[i][j][0], ub=U[i][j][1];
    const uaAlt=U[1-i][j][0], ubAlt=U[i][1-j][1];
    if(ua>=uaAlt && ub>=ubAlt) res.push([i,j]);
  }
  return res;
}

function mixedNE(game){
  const {U} = game;
  const a00=U[0][0][0], a01=U[0][1][0], a10=U[1][0][0], a11=U[1][1][0];
  const b00=U[0][0][1], b01=U[0][1][1], b10=U[1][0][1], b11=U[1][1][1];
  const denomQ=(a00-a10)+(a11-a01), denomP=(b00-b01)+(b11-b10);
  if(Math.abs(denomQ)<1e-12 || Math.abs(denomP)<1e-12) return null;
  const q=(a11-a01)/denomQ, p=(b11-b10)/denomP;
  if(p>=-1e-12 && p<=1+1e-12 && q>=-1e-12 && q<=1+1e-12){
    const clamp=x=>Math.max(0,Math.min(1,x));
    return {p:clamp(p), q:clamp(q)};
  }
  return null;
}

function agg(game, kind, i, j){
  // kind: 'util' -> sum of utilities (maximize), 'cost' -> sum of costs (minimize)
  const a = game.U[i][j][0], b = game.U[i][j][1];
  return a + b; // numbers are taken as utilities or costs by interpretation; dataset decides semantics
}
function aggMixed(game, kind, p, q){
  const U=game.U, probs=[[p*q,p*(1-q)],[(1-p)*q,(1-p)*(1-q)]];
  let eA=0,eB=0,eAgg=0; for(let i=0;i<2;i++) for(let j=0;j<2;j++){
    const pr=probs[i][j]; eA+=pr*U[i][j][0]; eB+=pr*U[i][j][1]; eAgg+=pr*(U[i][j][0]+U[i][j][1]);
  } return {eA,eB,eAgg};
}

function analyze(game, mode){
  const {players,Astr,Bstr,U}=game;
  const labels=[[`${Astr[0]},${Bstr[0]}`,`${Astr[0]},${Bstr[1]}`],[`${Astr[1]},${Bstr[0]}`,`${Astr[1]},${Bstr[1]}`]];
  const pure=pureNE(game), mix=mixedNE(game);
  const profiles=[[0,0],[0,1],[1,0],[1,1]];
  const rows=profiles.map(([i,j])=>({idx:[i,j],label:labels[i][j],payoff:U[i][j],AGG:agg(game,mode,i,j)}));

  let OPT=null, worst=null;
  if(mode==='util'){
    OPT = rows.reduce((a,b)=> a.AGG>=b.AGG? a : b);
  } else { // cost
    OPT = rows.reduce((a,b)=> a.AGG<=b.AGG? a : b);
  }

  const eqAgg=[];
  for(const [i,j] of pure){ eqAgg.push({ type:'pure', at:[i,j], label:labels[i][j], AGG: agg(game,mode,i,j) }); }
  let mixRow=null;
  if(mix){
    const m = aggMixed(game, mode, mix.p, mix.q);
    eqAgg.push({ type:'mixed', at:[mix.p,mix.q], label:'mixed', AGG: m.eAgg, eA:m.eA, eB:m.eB });
    mixRow = {p:mix.p, q:mix.q, eA:m.eA, eB:m.eB, eAGG:m.eAgg};
  }
  if(eqAgg.length===0){
    return { players, Astr, Bstr, pure, mix:null, rows, OPT, worst:null, PoA:null, mode, note:'Kein Gleichgewicht gefunden (weder pure noch innenliegendes mixed).' };
  }
  // worst eq depends on mode
  worst = eqAgg.reduce((a,b)=> (mode==='util' ? (a.AGG<=b.AGG? a : b) : (a.AGG>=b.AGG? a : b)));
  let PoA=null;
  if(mode==='util'){
    if(worst.AGG>1e-12) PoA = OPT.AGG / worst.AGG;
  } else { // cost
    if(OPT.AGG>1e-12) PoA = worst.AGG / OPT.AGG;
  }
  return { players, Astr, Bstr, pure, mix:mixRow, rows, OPT, worst, PoA, mode };
}

function fmt(x){ return Math.abs(x)<1e-9?'0':(Math.round(x*1e6)/1e6).toString(); }

function printText(r){
  const {players,Astr,Bstr,pure,mix,rows,OPT,worst,PoA,mode,note}=r;
  const aggName = mode==='util' ? 'SW' : 'SC';
  console.log(`Players: ${players[0]} (A) vs ${players[1]} (B)`);
  console.log(`Strategies A: ${Astr.join(', ')} | B: ${Bstr.join(', ')}`);
  console.log(`\nPayoffs & ${aggName}:`);
  for(const row of rows){ const [uA,uB]=row.payoff; console.log(`  ${row.label.padEnd(9)} -> (A:${uA}, B:${uB}), ${aggName}=${row.AGG}`); }
  console.log(`\nOPT: ${OPT.label} with ${aggName}=${OPT.AGG}`);
  if(pure.length){ console.log(`\nPure NE:`); for(const [i,j] of pure){ const r=rows.find(x=>x.idx[0]===i && x.idx[1]===j); console.log(`  ${r.label}  (${aggName}=${r.AGG})`);} } else { console.log('Pure NE: none'); }
  if(mix){ console.log(`Mixed NE: p(A=${Astr[0]})=${fmt(mix.p)}, q(B=${Bstr[0]})=${fmt(mix.q)}  -> E[${aggName}]=${fmt(mix.eAGG)} (A:${fmt(mix.eA)}, B:${fmt(mix.eB)})`); } else { console.log('Mixed NE: none (no interior)'); }
  if(note) console.log(`\nNote: ${note}`);
  const tag = mode==='util' ? 'PoA_util' : 'PoA_cost';
  if(PoA!=null) console.log(`\n${tag} = ${mode==='util' ? 'OPT / worst_EQ_'+aggName : 'worst_EQ_'+aggName+' / OPT'} = ${fmt(PoA)}`);
  else console.log(`\n${tag} = n/a (OPT=${fmt(OPT.AGG)}, worst_EQ_${aggName}=${fmt(worst?.AGG ?? 0)})`);
}

function printJSON(r){
  const aggName = r.mode==='util' ? 'SW' : 'SC';
  const out = {
    players: { A: r.players[0], B: r.players[1] },
    strategies: { A: r.Astr, B: r.Bstr },
    profiles: r.rows.map(x=>({ idx:x.idx, label:x.label, payoff:x.payoff, [aggName]: x.AGG })),
    pureNE: r.pure.map(([i,j])=>({ idx:[i,j], label: r.rows.find(y=>y.idx[0]===i && y.idx[1]===j).label })),
    mixedNE: r.mix ? { p:r.mix.p, q:r.mix.q, EA:r.mix.eA, EB:r.mix.eB, E_AGG:r.mix.eAGG } : null,
    optimum: { idx: r.OPT.idx || null, label: r.OPT.label, [aggName]: r.OPT.AGG },
    worstEQ: r.worst ? { at: r.worst.at, label: r.worst.label, [aggName]: r.worst.AGG } : null,
    metric: { mode: r.mode, name: aggName, PoA: r.PoA }
  };
  const _round=(k,v)=>typeof v==="number"?Number(v.toFixed(6)):v; console.log(JSON.stringify(out,_round));
}

function main(){
  const args = parseArgs(process.argv);
  if(!args.file){ console.error('Usage: node nash.js <gamefile> [--json] [--poa util|cost]'); process.exit(1); }
  const txt=fs.readFileSync(args.file,'utf8');
  const game=parseGame(txt);
  const res=analyze(game, args.poa==='cost' ? 'cost' : 'util');
  if(args.json) printJSON(res); else printText(res);
}
if(require.main===module){ try{ main(); } catch(e){ console.error('ERROR:', e.message); process.exit(2); } }