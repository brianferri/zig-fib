const std = @import("std");

pub const digit_t = u64;

const digits_bytes = @sizeOf(digit_t);
const digits_bits = @bitSizeOf(digit_t);

pub const Number = struct {
    bytes: []digit_t,
    length: usize,
};

pub fn fibonacci(n: u64, allocator: std.mem.Allocator) !Number {
    const result = iterativeFibonacci(n);

    const bit_count = digits_bits - @clz(result);
    const byte_count = @max((bit_count + 7) / 8, 1);

    const bytes: []digit_t = try allocator.alloc(digit_t, byte_count);
    std.mem.writeInt(digit_t, @ptrCast(bytes), result, .little);

    return .{
        .bytes = bytes,
        .length = byte_count,
    };
}

pub fn iterativeFibonacci(n: u64) digit_t {
    var a: digit_t = 0;
    var b: digit_t = 1;
    var i: digit_t = 0;

    while (i < n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }

    return a;
}
