import argparse, json, sys
from .nash2x2 import load_game, pure_nash, mixed_nash, poa

def main():
    ap = argparse.ArgumentParser(prog='lama.nash.runner', description='2x2 Nash checks + PoA')
    ap.add_argument('--in', dest='infile', required=True)
    ap.add_argument('--format', choices=['text','json'], default='text')
    ap.add_argument('--check', choices=['pure','mixed','all'], default='all')
    ap.add_argument('--poa', action='store_true')
    args = ap.parse_args()

    game = load_game(args.infile)
    out = {
        'players': ['A','B'],
        'strategies': {'A': list(game.A_strats), 'B': list(game.B_strats)},
        'payoffs': {'A': game.A, 'B': game.B},
        'nash_pure': None,
        'nash_mixed': None,
        'poa': None
    }

    if args.check in ('pure','all'):
        pn = pure_nash(game)
        out['nash_pure'] = [{'A': a, 'B': b, 'payoff': list(p)} for (a,b,p) in pn]

    if args.check in ('mixed','all'):
        mn = mixed_nash(game)
        out['nash_mixed'] = mn

    if args.poa:
        out['poa'] = poa(game, out['nash_pure'] or [], out['nash_mixed'])

    if args.format == 'json':
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"A: {game.A_strats} | B: {game.B_strats}")
        print("Payoffs A:", game.A)
        print("Payoffs B:", game.B)
        print("Pure NE:", out['nash_pure'])
        print("Mixed NE:", out['nash_mixed'])
        print("PoA:", out['poa'])

if __name__ == '__main__':
    main()
