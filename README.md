# Connect Four

A Goose port of John Tromp's Fhourstones Connect Four solver 

## Prerequisites

The [Goose](https://github.com/aardappel/goose) compiler - and its dependencies (e.g. clang or gcc).


## Verification

Checked against the original C (v3.2) and Java (v3.1) reference implementations, which agree
with each other exactly:

Position (moves played)          | Score | Nodes searched
:----------                      | :---- | -------------: 
45461667                         | Win   |        51,596  
35333571                         | Loss  |     8,716,732
13333111                         | Draw  |   169,704,432
(empty board, full 42-ply solve) | Win   | 1,479,113,766

Run the exact-node-count regression tests with:
```
time ./c4_solve <inputs
Fhourstones 3.2 (Goose)
Boardsize = 7x6
Using 8306069 transposition table entries of size 8 bytes.

Solving 8-ply position after 45461667 . . .
score = 5 (+)  work = 14
51596 pos / 3 msec = 17198.6 Kpos/sec

Solving 8-ply position after 35333571 . . .
score = 1 (-)  work = 21
8716732 pos / 265 msec = 32893.3 Kpos/sec

Solving 8-ply position after 13333111 . . .
score = 3 (=)  work = 26
169704432 pos / 5257 msec = 32281.6 Kpos/sec

Solving 0-ply position after  . . .
score = 5 (+)  work = 29
1479113766 pos / 43861 msec = 33722.7 Kpos/sec

48.63s user 0.27s system 96% cpu 50.725 total
```

## Usage: solve (benchmark / analysis)

Reads one position per line from stdin, as a string of column digits
(1–7, left to right); other characters are ignored, and an empty line
solves the starting position. This matches the original Fhourstones CLI
input format, so existing test/benchmark input files work unchanged.

```
echo "4453" | ./c4_solve
```

For each position it reports the game-theoretic score, log2 of positions
stored in the transposition table ("work"), total nodes searched, search
speed, and a histogram of stored transposition-table entries by score.



## References 

1. [John Tromp's Connect Four page](https://tromp.github.io/c4/c4.html)
2. [Fhourstones Benchmark](https://tromp.github.io/c4/fhour.html)
3. ["The Complete Book of Connect Four",  James Dow Allen](https://fabpedigree.com/james/C4/c4_book.htm)
4. [Wikipedia's Conect Four](https://en.wikipedia.org/wiki/Connect_Four)
5. [Minimax](https://en.wikipedia.org/wiki/Minimax)
6. [Monte Carlo Tree Search](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search)

