import math, os
from lama.nash.nash2x2 import load_game, pure_nash, mixed_nash, poa

BASE = os.path.join('lama','scenarios')

def test_prisoners_pure_and_poa():
    g = load_game(os.path.join(BASE, 'prisoners.nash'))
    pn = pure_nash(g)
    assert len(pn) == 1
    assert pn[0][0] == 'Defect' and pn[0][1] == 'Defect'
    P = poa(g, pn, None)
    assert abs(P['poa_pure'] - 3.0) < 1e-9

def test_bos_pure_mixed_poa():
    g = load_game(os.path.join(BASE, 'bos.nash'))
    pn = {(a,b) for (a,b,_) in pure_nash(g)}
    assert pn == {('Opera','Opera'), ('Football','Football')}
    mn = mixed_nash(g)
    assert mn is not None
    assert abs(mn['p_A_S1'] - (2/3)) < 1e-9
    assert abs(mn['q_B_T1'] - (1/3)) < 1e-9
    P = poa(g, [('Opera','Opera',(2,1)), ('Football','Football',(1,2))], mn)
    assert abs(P['poa_pure'] - 1.0) < 1e-9
    assert abs(P['poa_mixed'] - 2.25) < 1e-6

def test_matching_pennies_mixed_only():
    g = load_game(os.path.join(BASE, 'matching_pennies.nash'))
    pn = pure_nash(g)
    assert pn == []
    mn = mixed_nash(g)
    assert mn is not None
    assert abs(mn['p_A_S1'] - 0.5) < 1e-9
    assert abs(mn['q_B_T1'] - 0.5) < 1e-9
    P = poa(g, [], mn)
    assert math.isinf(P['poa_mixed'])
