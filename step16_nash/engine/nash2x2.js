/* step16_nash/engine/nash2x2.js */
const fs = require('fs');
const path = require('path');

function parseDSL(text){
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith('#'));
  const data = { payoffs: {} };
  for(const ln of lines){
    if(/^name\s*:/i.test(ln)){ data.name = ln.split(':')[1].trim(); continue; }
    if(/^type\s*:/i.test(ln)){ data.type = ln.split(':')[1].trim().toLowerCase(); continue; }
    if(/^players\s*:/i.test(ln)){ continue; } // fixed A,B
    if(/^A\s*:/i.test(ln)){ data.A = ln.split(':')[1].trim().split(',').map(s=>s.trim()); continue; }
    if(/^B\s*:/i.test(ln)){ data.B = ln.split(':')[1].trim().split(',').map(s=>s.trim()); continue; }
    if(/^payoffs\s*:/i.test(ln)){ continue; }
    // payoff line: s,t: a,b
    let m = ln.match(/^([A-Za-z0-9_]+)\s*,\s*([A-Za-z0-9_]+)\s*:\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
    if(m){
      const key = `${m[1]},${m[2]}`;
      data.payoffs[key] = [Number(m[3]), Number(m[4])];
    }
  }
  if(!data.A || !data.B || data.A.length!==2 || data.B.length!==2) throw new Error('DSL expects 2 strategies per player');
  // build matrices uA,uB (2x2) in order [A0/A1] x [B0/B1]
  const idx = (s, arr)=> arr.findIndex(x=>x.toLowerCase()===s.toLowerCase());
  function payoff(i,j){
    const key = `${data.A[i]},${data.B[j]}`;
    if(!(key in data.payoffs)) throw new Error(`Missing payoff for ${key}`);
    return data.payoffs[key];
  }
  const uA = [[0,0],[0,0]], uB = [[0,0],[0,0]];
  for(let i=0;i<2;i++) for(let j=0;j<2;j++){ const p = payoff(i,j); uA[i][j]=p[0]; uB[i][j]=p[1]; }
  return { name: data.name||'unnamed', type: data.type==='cost'?'cost':'util', A:data.A, B:data.B, uA, uB };
}

function bestResponses(u, byRows=true){
  // byRows=true -> best response of player A to each B column; else vice versa.
  const br = byRows ? [[],[]] : [[],[]]; // for each opponent action, set of best indices
  if(byRows){
    for(let col=0; col<2; col++){
      const a0 = u[0][col], a1 = u[1][col];
      const mx = Math.max(a0,a1);
      br[col] = [];
      if(a0===mx) br[col].push(0);
      if(a1===mx) br[col].push(1);
    }
  } else {
    for(let row=0; row<2; row++){
      const b0 = u[row][0], b1 = u[row][1];
      const mx = Math.max(b0,b1);
      br[row] = [];
      if(b0===mx) br[row].push(0);
      if(b1===mx) br[row].push(1);
    }
  }
  return br;
}

function pureNE(game){
  const Aresp = bestResponses(game.uA, true);   // A best responses to B's cols
  const Bresp = bestResponses(game.uB, false);  // B best responses to A's rows
  const list=[];
  for(let i=0;i<2;i++){
    for(let j=0;j<2;j++){
      const Aok = Aresp[j].includes(i);
      const Bok = Bresp[i].includes(j);
      if(Aok && Bok){
        const sw = game.uA[i][j] + game.uB[i][j];
        const cost = game.uA[i][j] + game.uB[i][j]; // for 'cost' interpret numbers as costs
        list.push({i,j, profile:`${game.A[i]},${game.B[j]}`, uA:game.uA[i][j], uB:game.uB[i][j], SW:sw, COST:cost});
      }
    }
  }
  return list;
}

function mixedNE(game){
  // Solve for p (A plays A0) s.t. B indifferent; and q (B plays B0) s.t. A indifferent
  const b = game.uB, a = game.uA;
  const denomP = (b[0][0]-b[1][0]) - (b[0][1]-b[1][1]); // (uB11 - uB21) - (uB12 - uB22)
  const denomQ = (a[0][0]-a[0][1]) - (a[1][0]-a[1][1]); // (uA11 - uA12) - (uA21 - uA22)
  if(denomP===0 || denomQ===0) return null;
  const p = (b[1][1]-b[1][0]) / denomP; // (uB22 - uB21)/denomP
  const q = (a[1][1]-a[0][1]) / denomQ; // (uA22 - uA12)/denomQ
  if(!(p>=0 && p<=1 && q>=0 && q<=1)) return null;

  const probs = [[p*q, p*(1-q)], [(1-p)*q, (1-p)*(1-q)]];
  let EA=0, EB=0;
  for(let i=0;i<2;i++){
    for(let j=0;j<2;j++){
      EA += probs[i][j]*game.uA[i][j];
      EB += probs[i][j]*game.uB[i][j];
    }
  }
  return { p, q, EA, EB, SW: EA+EB, COST: EA+EB };
}

function metrics(game){
  // list all outcomes
  const states = [];
  for(let i=0;i<2;i++) for(let j=0;j<2;j++){ states.push({i,j, SW: game.uA[i][j]+game.uB[i][j], COST: game.uA[i][j]+game.uB[i][j] }); }
  const pure = pureNE(game);
  const mixed = mixedNE(game);
  const equilibria = [...pure];
  if(mixed) equilibria.push({mixed:true, ...mixed});

  let optimum, worstEQ;
  if(game.type==='util'){
    optimum = states.reduce((m,s)=> Math.max(m, s.SW), -Infinity);
    if(equilibria.length===0) worstEQ = null;
    else worstEQ = equilibria.reduce((m,e)=> Math.min(m, e.mixed?e.SW : e.SW), Infinity);
  } else { // cost
    optimum = states.reduce((m,s)=> Math.min(m, s.COST), Infinity);
    if(equilibria.length===0) worstEQ = null;
    else worstEQ = equilibria.reduce((m,e)=> Math.max(m, e.mixed?e.COST : e.COST), -Infinity);
  }

  let PoA = null;
  if(game.type==='util' && worstEQ && worstEQ>0) PoA = Number((optimum / worstEQ).toFixed(6));
  if(game.type==='cost' && optimum && optimum>0 && worstEQ) PoA = Number((worstEQ / optimum).toFixed(6));

  return { pure, mixed: mixed||null, optimum: game.type==='util'? {SW:optimum} : {COST:optimum}, worstEQ: game.type==='util'? {SW:worstEQ} : {COST:worstEQ}, metric:{ PoA } };
}

function parseFile(fp){
  const txt = fs.readFileSync(fp,'utf8');
  return parseDSL(txt);
}

module.exports = { parseDSL, parseFile, pureNE, mixedNE, metrics };