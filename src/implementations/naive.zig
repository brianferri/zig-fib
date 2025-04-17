const std = @import("std");

pub const digit_t = u8;

pub const Number = struct {
    bytes: []digit_t,
    length: usize,

    pub fn print(self: Number, allocator: std.mem.Allocator) ![]u8 {
        const result: *u64 = @alignCast(@ptrCast(self.bytes));
        return try std.fmt.allocPrintZ(allocator, "{d}", .{result.*});
    }
};

pub fn fibonacci(n: u64, allocator: std.mem.Allocator) !Number {
    const result = naiveFib(n);

    const bit_count = 64 - @clz(result);
    const byte_count = (bit_count + 7) / 8;

    const bytes: *[8]digit_t = @ptrCast(try allocator.alloc(digit_t, 8));
    std.mem.writeInt(u64, bytes, result, .little);

    return .{
        .bytes = bytes,
        .length = byte_count,
    };
}

fn naiveFib(n: u64) u64 {
    if (n <= 1) return n;
    return naiveFib(n - 1) + naiveFib(n - 2);
}
