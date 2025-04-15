const std = @import("std");

pub const digits_t = u8;

pub const Number = struct {
    bytes: []digits_t,
    length: usize,
};

pub fn fibonacci(n: u64, allocator: std.mem.Allocator) !Number {
    const result = iterativeFibonacci(n);

    const bit_count = 64 - @clz(result);
    const byte_count = @max((bit_count + 7) / 8, 1);

    const bytes: *[8]digits_t = @ptrCast(try allocator.alloc(digits_t, 8));
    std.mem.writeInt(u64, bytes, result, .little);

    return Number{
        .bytes = bytes,
        .length = byte_count,
    };
}

pub fn iterativeFibonacci(n: u64) u64 {
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u64 = 0;

    while (i < n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }

    return a;
}
