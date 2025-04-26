const std = @import("std");

pub const digit_t = u64;
pub const dbdgt_t = u128;
const DIGIT_BIT = @bitSizeOf(digit_t);
const TUPLE_LEN = 3;

pub const Number = struct {
    bytes: []digit_t,
    length: usize,

    pub fn print(self: Number, allocator: std.mem.Allocator) ![]u8 {
        var temp = try allocator.alloc(digit_t, self.bytes.len);
        defer allocator.free(temp);
        @memcpy(temp, self.bytes);

        var digits = std.ArrayList(u8).init(allocator);

        while (true) {
            var remainder: u64 = 0;
            var all_zero = true;
            var i: usize = self.bytes.len;
            while (i > 0) : (i -= 1) {
                const value: u128 = (@as(u128, remainder) << 64) | temp[i - 1];
                const quotient: u64 = @intCast(value / 10);
                remainder = @intCast(value % 10);
                temp[i - 1] = quotient;
                if (quotient != 0) all_zero = false;
            }
            try digits.append(@intCast(remainder + '0'));
            if (all_zero) break;
        }

        var i: usize = digits.items.len;
        var reversed = try allocator.alloc(u8, digits.items.len);
        while (i > 0) : (i -= 1) {
            reversed[i - 1] = digits.items[digits.items.len - i];
        }
        return reversed;
    }
};

fn ndigit_estimate(index: u64) usize {
    return (2 * index + DIGIT_BIT - 1) / DIGIT_BIT + 2;
}

fn scale_accum_once(accum1: []digit_t, accum2: []digit_t, a: []const digit_t, scale: dbdgt_t, ndigits: usize) void {
    var carry1: dbdgt_t = 0;
    var carry2: dbdgt_t = 0;
    var offset: usize = 0;
    while (offset < ndigits) : (offset += 1) {
        const prod: dbdgt_t = @as(dbdgt_t, @intCast(a[offset])) * scale;

        const acc1: dbdgt_t = @as(dbdgt_t, @intCast(accum1[offset])) + prod + carry1;
        accum1[offset] = @intCast(acc1);
        carry1 = acc1 >> DIGIT_BIT;

        const acc2: dbdgt_t = @as(dbdgt_t, @intCast(accum2[offset])) + prod + carry2;
        accum2[offset] = @intCast(acc2);
        carry2 = acc2 >> DIGIT_BIT;
    }

    @as(*dbdgt_t, @ptrCast(@alignCast(&accum1[ndigits]))).* += carry1;
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum2[ndigits]))).* += carry2;
}

fn scale_accum_twice(accum1: []digit_t, accum2: []digit_t, a: []const digit_t, scale1: dbdgt_t, scale2: dbdgt_t, ndigits: usize) void {
    var carry1: dbdgt_t = 0;
    var carry2: dbdgt_t = 0;
    var offset: usize = 0;
    while (offset < ndigits) : (offset += 1) {
        const adig: dbdgt_t = @intCast(a[offset]);

        const acc1 = @as(dbdgt_t, @intCast(accum1[offset])) + adig * scale1 + carry1;
        accum1[offset] = @intCast(acc1);
        carry1 = acc1 >> DIGIT_BIT;

        const acc2 = @as(dbdgt_t, @intCast(accum2[offset])) + adig * scale2 + carry2;
        accum2[offset] = @intCast(acc2);
        carry2 = acc2 >> DIGIT_BIT;
    }

    @as(*dbdgt_t, @ptrCast(@alignCast(&accum1[ndigits]))).* += carry1;
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum2[ndigits]))).* += carry2;
}

fn multiply_once(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    b: []const digit_t,
    adigits: usize,
    bdigits: usize,
) void {
    var offset: usize = 0;
    while (offset < bdigits) : (offset += 1) {
        scale_accum_once(accum1[offset..], accum2[offset..], a, b[offset], adigits);
    }
}

fn multiply_twice(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    b1: []const digit_t,
    b2: []const digit_t,
    adigits: usize,
    bdigits: usize,
) void {
    var offset: usize = 0;

    while (offset < bdigits) : (offset += 1) {
        scale_accum_twice(accum1[offset..], accum2[offset..], a, b1[offset], b2[offset], adigits);
    }
}

fn multiply_twice_maxlen(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    b1: []const digit_t,
    b2: []const digit_t,
    adigits: usize,
    bdigits: usize,
) usize {
    multiply_twice(accum1, accum2, a, b1, b2, adigits, bdigits);

    var len = adigits + bdigits;
    while (true) : (len -= 1) {
        if (accum1[len] != 0 or accum2[len] != 0) {
            return len + 1;
        }
    }
}

fn zero_out(slice: []digit_t) void {
    @memset(slice, 0);
}

var ndigits_max: usize = 0;
// zig fmt: off
inline fn A(ptr: []digit_t) []digit_t { return ptr[ndigits_max .. 2 * ndigits_max]; }
inline fn B(ptr: []digit_t) []digit_t { return ptr[0..ndigits_max]; }
inline fn C(ptr: []digit_t) []digit_t { return ptr[2 * ndigits_max ..]; }
// zig fmt: on

fn swap(lhs: *[]digit_t, rhs: *[]digit_t) void {
    const tmp = lhs.*;
    lhs.* = rhs.*;
    rhs.* = tmp;
}

pub fn fibonacci(index: u64, allocator: std.mem.Allocator) !Number {
    ndigits_max = ndigit_estimate(index);

    var fib = try allocator.alloc(digit_t, TUPLE_LEN * ndigits_max);
    var accum = try allocator.alloc(digit_t, TUPLE_LEN * ndigits_max);
    var scratch = try allocator.alloc(digit_t, TUPLE_LEN * ndigits_max);
    defer allocator.free(accum);
    defer allocator.free(scratch);

    var fib_len: usize = 1;
    var accum_len: usize = 1;

    A(fib)[0] = 1;
    B(fib)[0] = 0;
    C(fib)[0] = 1;

    A(accum)[0] = 0;
    B(accum)[0] = 1;
    C(accum)[0] = 1;

    var idx = index;
    while (idx != 0) : (idx >>= 1) {
        if (idx & 1 != 0) {
            zero_out(scratch);

            multiply_twice(A(scratch), B(scratch), A(fib), A(accum), B(accum), fib_len, accum_len);
            multiply_once(A(scratch), C(scratch), B(fib), B(accum), fib_len, accum_len);
            fib_len = multiply_twice_maxlen(B(scratch), C(scratch), C(accum), B(fib), C(fib), accum_len, fib_len);
            swap(&fib, &scratch);
        }
        zero_out(scratch);

        multiply_twice(A(scratch), B(scratch), A(accum), A(accum), B(accum), accum_len, accum_len);
        multiply_once(A(scratch), C(scratch), B(accum), B(accum), accum_len, accum_len);
        accum_len = multiply_twice_maxlen(B(scratch), C(scratch), C(accum), B(accum), C(accum), accum_len, accum_len);
        swap(&accum, &scratch);
    }

    return Number{
        .bytes = B(fib),
        .length = fib_len * @sizeOf(digit_t),
    };
}
