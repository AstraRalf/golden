/* step16_nash/run.js */
const fs = require('fs');
const path = require('path');
const { parseFile, metrics } = require('./engine/nash2x2');

function ensureDir(d){ if(!fs.existsSync(d)) fs.mkdirSync(d, {recursive:true}); }

function main(){
  const src = process.argv[2] || 'step16_nash/examples';
  const out = process.argv[3] || 'step16_nash/ci_out_latest';
  ensureDir(out);

  const files = fs.readdirSync(src).filter(f => f.endsWith('.game'));
  for(const f of files){
    const fp = path.join(src,f);
    const g = parseFile(fp);
    const m = metrics(g);

    const base = path.basename(f, '.game'); // e.g. bos.util -> bos.util.json
    const jsonOut = path.join(out, `${base}.json`);
    const txtOut  = path.join(out,  `${base}.txt`);

    const payload = {
      game: g.name, type: g.type, A: g.A, B: g.B,
      optimum: m.optimum, worstEQ: m.worstEQ, metric: m.metric,
      pureNE: m.pure, mixedNE: m.mixed
    };
    fs.writeFileSync(jsonOut, JSON.stringify(payload, null, 2));

    let txt = `Game: ${g.name} [${g.type}]\nA=${g.A.join('/')}, B=${g.B.join('/')}\n`;
    if(m.pure && m.pure.length){ txt += `Pure NE: ` + m.pure.map(p=>p.profile).join(', ') + '\n'; }
    if(m.mixed){ txt += `Mixed NE: p(A0)=${m.mixed.p.toFixed(4)}, q(B0)=${m.mixed.q.toFixed(4)}\n`; }
    if(g.type==='util'){
      txt += `OPT(SW)=${m.optimum.SW}, worstEQ(SW)=${m.worstEQ.SW}, PoA=${m.metric.PoA}\n`;
    } else {
      txt += `OPT(COST)=${m.optimum.COST}, worstEQ(COST)=${m.worstEQ.COST}, PoA=${m.metric.PoA}\n`;
    }
    fs.writeFileSync(txtOut, txt);
    console.log('✓', f, '→', path.basename(jsonOut), '|', path.basename(txtOut));
  }
}

if(require.main === module){ main(); }

