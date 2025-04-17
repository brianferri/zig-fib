const std = @import("std");

pub const digit_t = u64;

pub const Number = struct {
    bytes: []digit_t,
    length: usize,

    pub fn print(self: Number) !void {
        // TODO maybe pass this as an argument
        const allocator = std.heap.page_allocator;
        try self.printDecimal(allocator);
    }

    fn printDecimal(self: Number, allocator: std.mem.Allocator) !void {
        const writer = std.io.getStdOut().writer();

        var temp = try allocator.alloc(digit_t, self.bytes.len);
        defer allocator.free(temp);
        @memcpy(temp, self.bytes);

        var digits = std.ArrayList(u8).init(allocator);
        defer digits.deinit();

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
        while (i > 0) : (i -= 1) {
            try writer.writeByte(digits.items[i - 1]);
        }
    }
};

fn ndigit_estimate(index: digit_t) usize {
    return (index + @bitSizeOf(digit_t) - 1) / @bitSizeOf(digit_t) + 1;
}

fn accumulate(a: []digit_t, b: []const digit_t, ndigits: usize) u1 {
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

fn swap(lhs: *[]digit_t, rhs: *[]digit_t) void {
    const tmp = lhs.*;
    lhs.* = rhs.*;
    rhs.* = tmp;
}

pub fn fibonacci(index: digit_t, allocator: std.mem.Allocator) !Number {
    const ndigits_max = ndigit_estimate(index);

    var cur = try allocator.alloc(digit_t, ndigits_max);
    var next = try allocator.alloc(digit_t, ndigits_max);
    defer allocator.free(next);

    cur[0] = 0;
    next[0] = 1;

    var ndigits: usize = 1;
    var idx = index;
    while (idx != 0) : (idx -= 1) {
        ndigits += accumulate(next, cur, ndigits);
        swap(&cur, &next);
    }

    return .{
        .bytes = cur,
        .length = ndigits * @sizeOf(digit_t),
    };
}
