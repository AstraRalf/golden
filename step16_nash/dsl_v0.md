# Step16 DSL v0 (2x2)

Minimale, zeilenbasierte DSL für 2x2-Spiele.

Felder:
- `name: ...`
- `type: util|cost`  (util = Nutzen maximieren, cost = Kosten minimieren)
- `players: A,B`
- `A: s1,s2`         (Strategien von A)
- `B: t1,t2`         (Strategien von B)
- `payoffs:`         (je Zeile: `s,t: a,b` – a=Auszahlung/Kosten A, b=Auszahlung/Kosten B)

Beispiel (Battle of the Sexes, util):
name: BoS (util)
type: util
players: A,B
A: Opera,Football
B: Opera,Football
payoffs:
  Opera,Opera: 3,2
  Opera,Football: 0,0
  Football,Opera: 0,0
  Football,Football: 2,3

