const std = @import("std");
const fib_lib = @import("zig_fib_lib");

const fibonacci = fib_lib.fibonacci;
const Number = fib_lib.Number;
const digit_t = fib_lib.digit_t;

const FIRST_CHECKPOINT = 93;
const SECOND_CHECKPOINT = 0x2d7;

const Timespec = struct {
    sec: i64,
    nsec: i64,
};

const SOFT_CUTOFF = Timespec{ .sec = 1, .nsec = 500_000_000 };
const HARD_CUTOFF = Timespec{ .sec = 1, .nsec = 0 };

const SLEEP_DURATION_NS = 1_000;
const THREAD_TIMEOUT_NS = 5 * std.time.ns_per_s;

const SAMPLE_LOG = 10;

const FibonacciArgs = struct {
    index: u64,
    result: Number,
    duration: Timespec,
    thread_completed: bool,
};

fn less(lhs: Timespec, rhs: Timespec) bool {
    return lhs.sec < rhs.sec or (lhs.sec == rhs.sec and lhs.nsec < rhs.nsec);
}

fn report(args: *const FibonacciArgs) void {
    std.debug.print("{:20} | {}.{:09} s | {} B\n", .{ args.index, args.duration.sec, args.duration.nsec, args.result.length });
}

fn measureFibonacciCall(args: *FibonacciArgs, allocator: std.mem.Allocator) !void {
    const start_time = std.time.nanoTimestamp();
    args.result = try fibonacci(args.index, allocator);
    const end_time = std.time.nanoTimestamp();
    const delta_ns = end_time - start_time;

    args.duration.sec = @intCast(@divTrunc(delta_ns, std.time.ns_per_s));
    args.duration.nsec = @intCast(@mod(delta_ns, std.time.ns_per_s));
    args.thread_completed = true;
}

fn evaluateFibonacci(index: u64, allocator: std.mem.Allocator) !FibonacciArgs {
    var args: FibonacciArgs = .{
        .index = index,
        .result = Number{ .bytes = &[_]digit_t{}, .length = 0 },
        .duration = Timespec{ .sec = 0, .nsec = 0 },
        .thread_completed = false,
    };

    var thread = try std.Thread.spawn(.{}, measureFibonacciCall, .{ &args, allocator });

    const start_time = std.time.nanoTimestamp();
    while (true) {
        std.time.sleep(SLEEP_DURATION_NS);
        if (args.thread_completed) {
            thread.join();
            return args;
        }
        const current_time = std.time.nanoTimestamp();
        if (current_time - start_time >= THREAD_TIMEOUT_NS) {
            thread.detach();
            args.thread_completed = false;
            return args;
        }
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cur_idx: u64 = 0;
    var best_idx: u64 = 0;

    std.debug.print("#   Fibonacci index  |   Time (s)   | Size (bytes)\n", .{});
    std.debug.print("# -------------------+--------------+--------------\n", .{});

    // First Checkpoint
    {
        var a: u64 = 0;
        var b: u64 = 1;
        var tmp: u64 = undefined;
        while (cur_idx < FIRST_CHECKPOINT) : (cur_idx += 1) {
            var args = try evaluateFibonacci(cur_idx, allocator);
            defer allocator.free(args.result.bytes);
            if (!args.thread_completed or !less(args.duration, SOFT_CUTOFF)) {
                break;
            }

            const result: *u64 = @alignCast(@ptrCast(args.result.bytes));
            if (args.result.length < @sizeOf(u64)) {
                const shift_size: u6 = @intCast(args.result.length * 8);
                result.* &= (@as(u64, @intCast(1)) << shift_size) - 1;
            }

            if (result.* != a) {
                std.debug.print("Failed to correctly compute F({}).\nExpected {}, but received {}.\n", .{ cur_idx, a, result });
                return;
            }

            report(&args);
            if (less(args.duration, HARD_CUTOFF)) {
                best_idx = cur_idx;
            }

            tmp = a + b;
            a = b;
            b = tmp;
        }
    }

    // Second Checkpoint
    {
        while (cur_idx <= SECOND_CHECKPOINT) : (cur_idx += 1) {
            var args = try evaluateFibonacci(cur_idx, allocator);
            if (!args.thread_completed or !less(args.duration, SOFT_CUTOFF)) {
                break;
            }

            report(&args);
            if (less(args.duration, HARD_CUTOFF)) {
                best_idx = cur_idx;
            }
        }
    }

    // Upper bound search
    while (true) {
        const args = try evaluateFibonacci(cur_idx, allocator);
        if (!args.thread_completed or !less(args.duration, HARD_CUTOFF)) {
            break;
        }
        best_idx = cur_idx;
        cur_idx += (cur_idx >> 1) - (cur_idx >> 3);
    }

    // with upper bound found, reiterate to find the best more carefully
    {
        const raw_delta = if (cur_idx > SECOND_CHECKPOINT) (cur_idx - SECOND_CHECKPOINT) >> SAMPLE_LOG else 1;
        const delta = @max(raw_delta, 1);

        cur_idx = SECOND_CHECKPOINT;
        while (true) {
            cur_idx += delta;
            var args = try evaluateFibonacci(cur_idx, allocator);
            if ((cur_idx > best_idx) and (!args.thread_completed or !less(args.duration, SOFT_CUTOFF))) {
                break;
            }
            report(&args);
            if ((cur_idx > best_idx) and less(args.duration, HARD_CUTOFF)) {
                best_idx = cur_idx;
            }
        }
    }
    std.debug.print("# Recorded best: {}\n", .{best_idx});
}
