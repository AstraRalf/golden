from __future__ import annotations
import re, json
from dataclasses import dataclass
from typing import List, Tuple, Dict, Optional

@dataclass
class Game2x2:
    players: Tuple[str, str]
    A_strats: Tuple[str, str]
    B_strats: Tuple[str, str]
    A: List[List[float]]  # payoffs for A: [[a11,a12],[a21,a22]]
    B: List[List[float]]  # payoffs for B: [[b11,b12],[b21,b22]]

def parse_scenario(text: str) -> Game2x2:
    lines = [l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith('#')]
    # Players/strategies
    pmap: Dict[str, List[str]] = {}
    payoffs: Dict[Tuple[str,str], Tuple[float,float]] = {}
    payoff_rx = re.compile(r'^\(([^,]+),([^)]+)\)\s*=\s*([+-]?\d+(?:\.\d+)?),\s*([+-]?\d+(?:\.\d+)?)$')
    header_done = 0
    for l in lines:
        if ':' in l and header_done < 2 and '(' not in l:
            k, v = [x.strip() for x in l.split(':', 1)]
            pmap[k] = [s.strip() for s in v.split(',')]
            header_done += 1
        else:
            m = payoff_rx.match(l)
            if not m:
                # allow headers to be interleaved safely
                if ':' in l and '(' not in l:
                    k, v = [x.strip() for x in l.split(':', 1)]
                    pmap[k] = [s.strip() for s in v.split(',')]
                    continue
                raise ValueError(f'Invalid payoff line: {l}')
            a_s, b_s, pa, pb = m.groups()
            payoffs[(a_s.strip(), b_s.strip())] = (float(pa), float(pb))

    if len(pmap) != 2 or 'A' not in pmap or 'B' not in pmap:
        raise ValueError('Need exactly two players: lines starting with \"A:\" and \"B:\"')
    if len(pmap['A']) != 2 or len(pmap['B']) != 2:
        raise ValueError('Exactly two strategies per player are required.')
    S1, S2 = pmap['A']
    T1, T2 = pmap['B']
    profiles = [(S1,T1),(S1,T2),(S2,T1),(S2,T2)]
    if any(p not in payoffs for p in profiles):
        missing = [p for p in profiles if p not in payoffs]
        raise ValueError(f'Missing payoff entries for profiles: {missing}')

    A = [[0.0,0.0],[0.0,0.0]]
    B = [[0.0,0.0],[0.0,0.0]]
    A[0][0], B[0][0] = payoffs[(S1,T1)]
    A[0][1], B[0][1] = payoffs[(S1,T2)]
    A[1][0], B[1][0] = payoffs[(S2,T1)]
    A[1][1], B[1][1] = payoffs[(S2,T2)]
    return Game2x2(players=('A','B'), A_strats=(S1,S2), B_strats=(T1,T2), A=A, B=B)

def best_responses(game: Game2x2):
    # For each column j (B's choice), find A's best responses
    A_best = [[False, False],[False, False]]
    for j in range(2):
        col = [game.A[0][j], game.A[1][j]]
        maxv = max(col)
        for i in range(2):
            if game.A[i][j] >= maxv - 1e-12:
                A_best[i][j] = True
    # For each row i (A's choice), find B's best responses
    B_best = [[False, False],[False, False]]
    for i in range(2):
        row = [game.B[i][0], game.B[i][1]]
        maxv = max(row)
        for j in range(2):
            if game.B[i][j] >= maxv - 1e-12:
                B_best[i][j] = True
    return A_best, B_best

def pure_nash(game: Game2x2) -> List[Tuple[str,str,Tuple[float,float]]]:
    A_best, B_best = best_responses(game)
    out = []
    namesA, namesB = game.A_strats, game.B_strats
    for i in range(2):
        for j in range(2):
            if A_best[i][j] and B_best[i][j]:
                out.append( (namesA[i], namesB[j], (game.A[i][j], game.B[i][j])) )
    return out

def mixed_nash(game: Game2x2) -> Optional[Dict[str, float]]:
    a11,a12 = game.A[0]
    a21,a22 = game.A[1]
    b11,b12 = game.B[0]
    b21,b22 = game.B[1]

    den_q = (a11 - a21) - (a12 - a22)
    den_p = (b11 - b21) - (b12 - b22)

    if abs(den_q) < 1e-12 or abs(den_p) < 1e-12:
        return None
    q = (a22 - a12) / den_q
    p = (b22 - b21) / den_p
    if -1e-12 <= p <= 1+1e-12 and -1e-12 <= q <= 1+1e-12:
        p = min(max(p, 0.0), 1.0)
        q = min(max(q, 0.0), 1.0)
        return {'p_A_S1': p, 'p_A_S2': 1-p, 'q_B_T1': q, 'q_B_T2': 1-q}
    return None

def welfare(game: Game2x2, i:int, j:int) -> float:
    return game.A[i][j] + game.B[i][j]

def poa(game: Game2x2, pure_eq: List[Tuple[str,str,Tuple[float,float]]], mixed_eq: Optional[Dict[str,float]]):
    # Social optimum
    SW = [welfare(game, i, j) for i in range(2) for j in range(2)]
    opt = max(SW)

    poa_pure = None
    if pure_eq:
        idx = []
        for (sa, sb, _) in pure_eq:
            i = 0 if sa == game.A_strats[0] else 1
            j = 0 if sb == game.B_strats[0] else 1
            idx.append( welfare(game, i, j) )
        worst_NE = min(idx)
        poa_pure = opt / worst_NE if worst_NE != 0 else float('inf')

    poa_mixed = None
    if mixed_eq:
        p = mixed_eq['p_A_S1']; q = mixed_eq['q_B_T1']
        # expected welfare under (p,q)
        import itertools
        probs = [p*q, p*(1-q), (1-p)*q, (1-p)*(1-q)]
        ws = [welfare(game, i, j) for i in range(2) for j in range(2)]
        ew = sum(pi*wi for pi,wi in zip(probs, ws))
        poa_mixed = opt / ew if ew != 0 else float('inf')

    return {'optimum': opt, 'poa_pure': poa_pure, 'poa_mixed': poa_mixed}

def load_game(path: str) -> Game2x2:
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    return parse_scenario(text)
