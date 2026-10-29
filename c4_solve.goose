// Connect Four solver: John Tromp's Fhourstones algorithm in Goose.
//
// Reads one position per line from stdin (column digits 1..7, other characters
// ignored; an empty line is the empty board) and prints score, work and node
// count in the format of the Fhourstones reference implementations.
//
//   goose build c4_solve.goose && echo 45461667 | ./c4_solve
//
// The search plays and unplays moves in place on one Board, and all state lives
// in the globals below; the transposition table is resized once in main.

import std;
import os;

// ---- board geometry (bit index = col * H1 + row, row 0 at the bottom) ------

let WIDTH: i32 = 7;
let HEIGHT: i32 = 6;
let H1: i32 = 7;
let H2: i32 = 8;
let SIZE: i32 = 42;
let SIZE1: i32 = 49;

let COL1: u64 = 0x7f;
let BOTTOM: u64 = 0x40810204081;   // one bit at the bottom of every column
let TOP: u64 = 0x1020408102040;    // the guard row above every column

// ---- scores, as in Fhourstones: negation is LOSSWIN - x --------------------

let UNKNOWN: i32 = 0;
let LOSS: i32 = 1;
let DRAWLOSS: i32 = 2;
let DRAW: i32 = 3;
let DRAWWIN: i32 = 4;
let WIN: i32 = 5;
let LOSSWIN: i32 = 6;

// ---- transposition table ---------------------------------------------------
//
// One u64 per bucket, holding two entries for the same bucket:
//   bits  0..26  new_lock    bits 26..29  new_score
//   bits 29..32  big_score   bits 32..58  big_lock    bits 58..64  big_work
// The "big" entry is replaced when the new one has at least as much work, or
// the same lock; the "new" entry always takes the displaced position.

let TT_SIZE = 8306069;           // a prime of about 2^(SIZE1 - LOCKSIZE)
let LOCKSIZE: i32 = 26;
let LOCK_MASK: u64 = 0x3ffffff;
let NEW_MASK: u64 = 0x1fffffff;       // new_lock + new_score
let SYMMREC: i32 = 10;                // plies for which mirror positions share an entry

var tt: u64[>..] = [];             // resized once in main, in place on its own data stack
var posed: i64 = 0;                   // table stores so far, for the "work" figure

fn big_work(x: u64) -> i32 { (x >> 58) as i32 }
fn big_lock(x: u64) -> u64 { (x >> 32) & LOCK_MASK }
fn big_score(x: u64) -> i32 { ((x >> 29) & 7) as i32 }
fn new_lock(x: u64) -> u64 { x & LOCK_MASK }
fn new_score(x: u64) -> i32 { ((x >> 26) & 7) as i32 }

fn tt_clear() {
    for i in tt.len { tt[i] = 0; }
    posed = 0;
}

// The score stored for `lock` in bucket entry `he`, or UNKNOWN.
fn entry_score(he: u64, lock: u64) -> i32 {
    if lock == big_lock(he) { return big_score(he); }
    if lock == new_lock(he) { return new_score(he); }
    return UNKNOWN;
}

// The bucket entry after storing (lock, score, work) into `he`.
fn entry_store(he: u64, lock: u64, score: i32, work: i32) -> u64 {
    if lock == big_lock(he) || work >= big_work(he) {
        let packed = (((work as u64) << LOCKSIZE) | lock) << 3 | (score as u64);
        return (packed << 29) | (he & NEW_MASK);
    }
    return (he & ~NEW_MASK) | ((score as u64) << LOCKSIZE) | lock;
}

fn mirror_columns(x: u64) -> u64 {
    var rest = x;
    var mirrored: u64 = 0;
    while rest != 0 {
        mirrored = (mirrored << H1) | (rest & COL1);
        rest >>= H1;
    }
    return mirrored;
}

// ---- board -----------------------------------------------------------------

struct Board {
    color: u64[2],      // stones of the player who moves on even / odd plies
    height: i32[7],     // bit index of the next free square per column
    nplies: i32,
}

fn new_board() -> Board {
    var b = Board { color: [0, 0], height: [0; 7], nplies: 0 };
    for c in WIDTH { b.height[c] = c * H1; }
    return b;
}

fn is_legal(bb: u64) -> bool { (bb & TOP) == 0 }

fn has_won(bb: u64) -> bool {
    let diag1 = bb & (bb >> HEIGHT);
    let hori = bb & (bb >> H1);
    let diag2 = bb & (bb >> H2);
    let vert = bb & (bb >> 1);
    let win = (diag1 & (diag1 >> (2 * HEIGHT))) | (hori & (hori >> (2 * H1)))
            | (diag2 & (diag2 >> (2 * H2))) | (vert & (vert >> 2));
    return win != 0;
}

fn is_legal_has_won(bb: u64) -> bool { is_legal(bb) && has_won(bb) }

// Drops a stone for the player to move; the caller has checked legality.
fn play(b: Board&, col: i32) {
    b.color[b.nplies & 1] ^= 1 as u64 << b.height[col];
    b.height[col] += 1;
    b.nplies += 1;
}

// Undoes the last move, which was in column `col`.
fn unplay(b: Board&, col: i32) {
    b.nplies -= 1;
    b.height[col] -= 1;
    b.color[b.nplies & 1] ^= 1 as u64 << b.height[col];
}

// Position code; mirror images share one in the opening.
fn hash_code(b: Board&) -> u64 {
    var code = b.color[b.nplies & 1] + b.color[0] + b.color[1] + BOTTOM;
    if b.nplies < SYMMREC {
        let m = mirror_columns(code);
        if m < code { code = m; }
    }
    return code;
}

// ---- search ------------------------------------------------------------------

var history: i32[128];      // move-ordering heuristic: (side << 6) + bit index (at most 48)
var nodes: i64 = 0;

fn init_history() {
    for side in 2 {
        for i in (WIDTH + 1) / 2 {
            for h in H1 / 2 {
                let val = 4 + min(i, 3)
                        + max(min(h, 3) - max(3 - i, 0), -1)
                        + min(min(i, h), 3)
                        + min(h, 3);
                history[(side << 6) + H1 * i + h] = val;
                history[(side << 6) + H1 * (WIDTH - 1 - i) + HEIGHT - 1 - h] = val;
                history[(side << 6) + H1 * i + HEIGHT - 1 - h] = val;
                history[(side << 6) + H1 * (WIDTH - 1 - i) + h] = val;
            }
        }
    }
}

// Safe columns as a bit mask (bit c = column c): playable and not handing the
// opponent an immediate win. Returns (forced score, mask); a nonzero score means
// the position is already decided (unstoppable threat, or no safe move).
fn candidates(b: Board&) -> i32, u32 {
    let other = b.color[(b.nplies + 1) & 1];
    var cand: u32 = 0;
    for i in WIDTH {
        let newbrd = other | (1 as u64 << b.height[i]);
        if !is_legal(newbrd) { continue; }
        let winontop = is_legal_has_won(other | (2 as u64 << b.height[i]));
        if has_won(newbrd) {
            // The opponent would win here, so we must block it - unless that
            // hands them a win on top, or they have a second threat elsewhere.
            if winontop { return LOSS, 0; }
            for j in i + 1..WIDTH {
                if is_legal_has_won(other | (1 as u64 << b.height[j])) { return LOSS, 0; }
            }
            return UNKNOWN, 1 as u32 << i;
        }
        if !winontop { cand |= 1 as u32 << i; }
    }
    if cand == 0 { return LOSS, 0; }
    return UNKNOWN, cand;
}

fn intlog(n: i64) -> i32 {
    var work: i32 = 0;
    var x = n >> 1;
    while x != 0 { work += 1; x >>= 1; }
    return work;
}

recursive fn ab(b: Board&, alpha0: i32, beta0: i32) -> i32 {
    nodes += 1;
    if b.nplies == SIZE - 1 { return DRAW; }    // one move left, and the mover cannot win
    let side = b.nplies & 1;
    let forced, cand = candidates(b);
    if forced != 0 { return forced; }
    if b.nplies == SIZE - 2 { return DRAW; }    // two left, no immediate win possible
    if popcount(cand) == 1 {
        let col = ctz(cand) as i32;
        play(b, col);
        let val = LOSSWIN - ab(b, LOSSWIN - beta0, LOSSWIN - alpha0);
        unplay(b, col);
        return val;
    }

    var alpha = alpha0;
    var beta = beta0;
    let code = hash_code(b);
    let lock = code >> (SIZE1 - LOCKSIZE);
    let index = (code as i64) % TT_SIZE;
    assert(tt.len == TT_SIZE);
    let ttscore = entry_score(tt[index], lock);
    if ttscore != UNKNOWN {
        if ttscore == DRAWLOSS {
            beta = DRAW;
            if beta <= alpha { return ttscore; }
        } else if ttscore == DRAWWIN {
            alpha = DRAW;
            if alpha >= beta { return ttscore; }
        } else {
            return ttscore;                     // exact score already known
        }
    }

    let posed_before = posed;
    var remaining = cand;       // columns not yet tried
    var tried: u32 = 0;         // columns tried so far, in the order tried
    var score = LOSS;
    while remaining != 0 {
        // Best history value first; the lowest column wins a tie.
        var col: i32 = 0;
        var best: i32 = -2147483647;
        for c in WIDTH {
            if ((remaining >> c) & 1) != 0 {
                let v = history[(side << 6) + (b.height[c] & 63)];
                if v > best { best = v; col = c; }
            }
        }
        remaining &= ~(1 as u32 << col);

        play(b, col);
        let val = LOSSWIN - ab(b, LOSSWIN - beta, LOSSWIN - alpha);
        unplay(b, col);
        if val > score {
            score = val;
            if score > alpha {
                alpha = score;
                if alpha >= beta {
                    // A cutoff at exactly DRAW with moves left untried only
                    // proves "at least a draw".
                    if score == DRAW && remaining != 0 { score = DRAWWIN; }
                    // Reward the cutoff move, penalise those tried before it.
                    if tried != 0 {
                        for c in WIDTH {
                            if ((tried >> c) & 1) != 0 { history[(side << 6) + (b.height[c] & 63)] -= 1; }
                        }
                        history[(side << 6) + (b.height[col] & 63)] += popcount(tried) as i32;
                    }
                    break;
                }
            }
        }
        tried |= 1 as u32 << col;
    }

    // An upper bound from the table meeting a new lower bound is exact.
    if score == LOSSWIN - ttscore { score = DRAW; }
    let work = intlog(posed - posed_before);
    posed += 1;
    tt[index] = entry_store(tt[index], lock, score, work);
    return score;
}

// Score of the position on `b` for the player to move.
fn solve(b: Board&) -> i32 {
    nodes = 0;
    let side = b.nplies & 1;
    if has_won(b.color[(b.nplies + 1) & 1]) { return LOSS; }
    for col in WIDTH {
        if is_legal_has_won(b.color[side] | (1 as u64 << b.height[col])) { return WIN; }
    }
    init_history();
    return ab(b, LOSS, WIN);
}

// Appends `prefix` and n / total to `out`, with three decimals.
fn add_share(out: u8[>..]&, prefix: u8[:], n: i64, total: i64) {
    format(out, prefix);
    format_flt(out, n as f64 / total, 3);
}

// Prints the share of table entries holding each score, as the reference
// implementations do: - loss, < draw or loss, = draw, > draw or win, + win.
fn tt_stats() {
    var count: i64[8] = [0; 8];
    for i in tt.len {
        let he = tt[i];
        if big_lock(he) != 0 { count[big_score(he)] += 1; }
        if new_lock(he) != 0 { count[new_score(he)] += 1; }
    }
    var total: i64 = 0;
    for s in LOSS..WIN + 1 { total += count[s]; }
    if total == 0 { return; }
    var out: u8[>..] = [];
    add_share(out, "- ", count[LOSS], total);
    add_share(out, "  < ", count[DRAWLOSS], total);
    add_share(out, "  = ", count[DRAW], total);
    add_share(out, "  > ", count[DRAWWIN], total);
    add_share(out, "  + ", count[WIN], total);
    print(out);
}

// ---- driver ------------------------------------------------------------------

fn score_char(s: i32) -> u8[:] {
    match s { 1 => "-", 2 => "<", 3 => "=", 4 => ">", 5 => "+", _ => "#" }
}

fn main() {
    tt.resize(TT_SIZE, 0);
    print("Fhourstones 3.2 (Goose)");
    print("Boardsize = ", WIDTH, "x", HEIGHT);
    print("Using ", TT_SIZE, " transposition table entries of size 8 bytes.");

    var line: u8[>..] = [];
    while read_line(line) {
        var b = new_board();
        var moves: u8[>..] = [];
        for ch in line {
            if ch >= '1' && ch <= '7' { play(b, ch - '1'); moves.push(ch); }
        }
        print("");
        print("Solving ", b.nplies, "-ply position after ", moves, " . . .");

        tt_clear();
        let t0 = clock_ns();
        let score = solve(b);
        let ms = max((clock_ns() - t0) / 1000000, 1);
        print("score = ", score, " (", score_char(score), ")  work = ", intlog(posed));
        let kpos10 = nodes * 10 / ms;
        print(nodes, " pos / ", ms, " msec = ", kpos10 / 10, ".", kpos10 % 10, " Kpos/sec");
        tt_stats();
        line.clear();
    }
}
