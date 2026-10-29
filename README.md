# Connect Four

A Goose port of John Tromp's Fhourstones Connect Four solver 

## Prerequisites

The [Goose](https://github.com/aardappel/goose) compiler - and its dependencies (e.g. clang or gcc).

## Build

Build a native executable with `make`, or directly with

```sh
goose build c4_solve.goose
```

`goose run c4_solve.goose` also works, but it compiles in-process with a slower backend
(about 2.8 times slower here), so use the native build for benchmarks.


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



## Verification

Checked against the original C (v3.2) and Java (v3.1) reference implementations, which agree
with each other exactly:

Position (moves played)          | Score | Nodes searched
:----------                      | :---- | -------------: 
45461667                         | Win   |        51,596  
35333571                         | Loss  |     8,716,732
13333111                         | Draw  |   169,704,432
(empty board, full 42-ply solve) | Win   | 1,479,113,766

Check the scores, node counts and table statistics against `expected.txt` with:
```sh
make test
```

`make bench` runs the same positions and prints the timings:

```sh
time make bench
./c4_solve < inputs
Fhourstones 3.2 (Goose)
Boardsize = 7x6
Using 8306069 transposition table entries of size 8 bytes.

Solving 8-ply position after 45461667 . . .
score = 5 (+)  work = 14
51596 pos / 2 msec = 25798.0 Kpos/sec
- 0.281  < 0.000  = 0.001  > 0.001  + 0.716

Solving 8-ply position after 35333571 . . .
score = 1 (-)  work = 21
8716732 pos / 251 msec = 34728.0 Kpos/sec
- 0.271  < 0.036  = 0.020  > 0.089  + 0.584

Solving 8-ply position after 13333111 . . .
score = 3 (=)  work = 26
169704432 pos / 5397 msec = 31444.2 Kpos/sec
- 0.216  < 0.144  = 0.021  > 0.242  + 0.377

Solving 0-ply position after  . . .
score = 5 (+)  work = 29
1479113766 pos / 41886 msec = 35312.8 Kpos/sec
- 0.249  < 0.125  = 0.027  > 0.191  + 0.408
47.43s user 0.12s system 99% cpu 47.663 total
```

Tested with Goose v2026.3-141-gcce94b91 (runtime f2981814a754) and Apple clang version 21.0.0 (clang-2100.1.1.101) on a Macbook Air M5.

On the same benchmark and same laptop, the original [original C](https://github.com/tromp/fhourstones/) implementation is roughly level and the 
[Rust](https://github.com/jesper-olsen/connect-four) implementation ~10% slower.



## References 

1. [John Tromp's Connect Four page](https://tromp.github.io/c4/c4.html)
2. [Fhourstones Benchmark](https://tromp.github.io/c4/fhour.html)
3. ["The Complete Book of Connect Four", James Dow Allen](https://fabpedigree.com/james/C4/c4_book.htm)
4. [Wikipedia's Connect Four](https://en.wikipedia.org/wiki/Connect_Four)
5. [Minimax](https://en.wikipedia.org/wiki/Minimax)
6. [Monte Carlo Tree Search](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search)

