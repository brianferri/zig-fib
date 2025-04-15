const std = @import("std");

pub const digits_t = u64;

pub const Number = struct {
    bytes: []digits_t,
    length: usize,
};

fn ndigit_estimate(index: digits_t) usize {
    return (index + @bitSizeOf(digits_t) - 1) / @bitSizeOf(digits_t) + 1;
}

fn accumulate(a: []digits_t, b: []const digits_t, ndigits: usize) u1 {
    var carry: u1 = 0;
    var offset: usize = 0;
    while (offset < ndigits) : (offset += 1) {
        var add = b[offset];
        const overflow1 = @addWithOverflow(add, carry);
        add = overflow1[0];
        carry = overflow1[1];

        const overflow2 = @addWithOverflow(a[offset], add);
        a[offset] = overflow2[0];
        carry += overflow2[1];
    }
    a[ndigits] = carry;
    return carry;
}

fn swap(lhs: *[]digits_t, rhs: *[]digits_t) void {
    const tmp = lhs.*;
    lhs.* = rhs.*;
    rhs.* = tmp;
}

pub fn fibonacci(index: digits_t, allocator: std.mem.Allocator) !Number {
    const ndigits_max = ndigit_estimate(index);
    std.debug.print("Allocating {} digits of size {}.\n", .{ ndigits_max, @sizeOf(digits_t) });

    var cur = try allocator.alloc(digits_t, ndigits_max);
    var next = try allocator.alloc(digits_t, ndigits_max);
    defer allocator.free(next);

    cur[0] = 0;
    next[0] = 1;

    var ndigits: usize = 1;
    var idx = index;
    while (idx != 0) : (idx -= 1) {
        ndigits += accumulate(next, cur, ndigits);
        swap(&cur, &next);
    }

    return Number{
        .bytes = cur,
        .length = ndigits * @sizeOf(digits_t),
    };
}
