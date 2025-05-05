const std = @import("std");

pub const digit_t = u64;
pub const dbdgt_t = u128;
const DIGIT_BIT = @bitSizeOf(digit_t);
const TUPLE_LEN = 2;

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

fn scale_accum(accum: []digit_t, a: []const digit_t, scale: dbdgt_t, ndigits: usize) void {
    var carry: dbdgt_t = 0;
    var i: usize = 0;
    while (i < ndigits) : (i += 1) {
        const acc = @as(dbdgt_t, accum[i]) + @as(dbdgt_t, a[i]) * scale + carry;
        accum[i] = @intCast(acc);
        carry = acc >> DIGIT_BIT;
    }
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum[ndigits]))).* += carry;
}

fn scale_accum_twice(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    scale1: dbdgt_t,
    scale2: dbdgt_t,
    ndigits: usize,
) void {
    var carry1: dbdgt_t = 0;
    var carry2: dbdgt_t = 0;
    var i: usize = 0;
    while (i < ndigits) : (i += 1) {
        const adig: dbdgt_t = @intCast(a[i]);

        const acc1 = @as(dbdgt_t, accum1[i]) + adig * scale1 + carry1;
        accum1[i] = @intCast(acc1);
        carry1 = acc1 >> DIGIT_BIT;

        const acc2 = @as(dbdgt_t, accum2[i]) + adig * scale2 + carry2;
        accum2[i] = @intCast(acc2);
        carry2 = acc2 >> DIGIT_BIT;
    }
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum1[ndigits]))).* += carry1;
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum2[ndigits]))).* += carry2;
}

fn scale_accum_dup(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    scale: dbdgt_t,
    ndigits: usize,
) void {
    var carry1: dbdgt_t = 0;
    var carry2: dbdgt_t = 0;
    var i: usize = 0;
    while (i < ndigits) : (i += 1) {
        const prod: dbdgt_t = @as(dbdgt_t, a[i]) * scale;

        const acc1 = @as(dbdgt_t, accum1[i]) + prod + carry1;
        accum1[i] = @intCast(acc1);
        carry1 = acc1 >> DIGIT_BIT;

        const acc2 = @as(dbdgt_t, accum2[i]) + prod + carry2;
        accum2[i] = @intCast(acc2);
        carry2 = acc2 >> DIGIT_BIT;
    }
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum1[ndigits]))).* += carry1;
    @as(*dbdgt_t, @ptrCast(@alignCast(&accum2[ndigits]))).* += carry2;
}

fn multiply(
    accum: []digit_t,
    a: []const digit_t,
    b: []const digit_t,
    adigits: usize,
    bdigits: usize,
) usize {
    var i: usize = 0;
    while (i < bdigits) : (i += 1) {
        scale_accum(accum[i..], a, b[i], adigits);
    }

    var len = adigits + bdigits;
    while (true) : (len -= 1) {
        if (accum[len] != 0) return len + 1;
    }
    return 0;
}

fn multiply_twice(
    accum1: []digit_t,
    accum2: []digit_t,
    a1: []const digit_t,
    a2: []const digit_t,
    b2: []const digit_t,
    maxlen1: usize,
    maxlen2: usize,
) void {
    var i: usize = 0;
    while (i < maxlen2) : (i += 1) {
        scale_accum_twice(accum1[i..], accum2[i..], a1, a2[i], b2[i], maxlen1);
    }
}

fn multiply_dup(
    accum1: []digit_t,
    accum2: []digit_t,
    a: []const digit_t,
    b: []const digit_t,
    adigits: usize,
    bdigits: usize,
) void {
    var i: usize = 0;
    while (i < bdigits) : (i += 1) {
        scale_accum_dup(accum1[i..], accum2[i..], a, b[i], adigits);
    }
}

fn swap(lhs: *[]digit_t, rhs: *[]digit_t) void {
    const tmp = lhs.*;
    lhs.* = rhs.*;
    rhs.* = tmp;
}

fn zero_out(slice: []digit_t) void {
    @memset(slice, 0);
}

var ndigits_max: usize = 0;
// zig fmt: off
inline fn A(ptr: []digit_t) []digit_t { return ptr[ndigits_max .. 2 * ndigits_max]; }
inline fn B(ptr: []digit_t) []digit_t { return ptr[0..ndigits_max]; }
// zig fmt: on

pub fn fibonacci(index: u64, allocator: std.mem.Allocator) !Number {
    ndigits_max = ndigit_estimate(index);

    const total_len = TUPLE_LEN * ndigits_max;

    var fib = try allocator.alloc(digit_t, total_len);
    var accum = try allocator.alloc(digit_t, total_len);
    var scratch = try allocator.alloc(digit_t, total_len);
    defer allocator.free(accum);
    defer allocator.free(scratch);

    var fib_len: usize = 1;
    var accum_len: usize = 1;

    A(fib)[0] = 1;
    B(fib)[0] = 0;

    A(accum)[0] = 0;
    B(accum)[0] = 1;

    var i = index;
    while (i != 0) : (i >>= 1) {
        if (i & 1 != 0) {
            zero_out(scratch);

            multiply_twice(A(scratch), B(scratch), A(fib), A(accum), B(accum), fib_len, accum_len);
            multiply_dup(A(scratch), B(scratch), B(fib), B(accum), fib_len, accum_len);
            fib_len = multiply(B(scratch), B(fib), A(accum), fib_len, accum_len);
            swap(&fib, &scratch);
        }
        zero_out(scratch);

        multiply_twice(A(scratch), B(scratch), A(accum), A(accum), B(accum), accum_len, accum_len);
        multiply_dup(A(scratch), B(scratch), B(accum), B(accum), accum_len, accum_len);
        accum_len = multiply(B(scratch), B(accum), A(accum), accum_len, accum_len);
        swap(&accum, &scratch);
    }

    return Number{
        .bytes = B(fib),
        .length = fib_len * @sizeOf(digit_t),
    };
}
