const std = @import("std");

pub const Number = struct {
    bytes: []u8,
    length: usize,
};

pub fn fibonacci(n: u64, allocator: std.mem.Allocator) !Number {
    const result = iterativeFibonacci(n);

    const bit_count = 64 - @clz(result);
    const byte_count = @max((bit_count + 7) / 8, 1);

    const bytes: *[8]u8 = @ptrCast(try allocator.alloc(u8, 8));
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
