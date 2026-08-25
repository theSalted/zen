const std = @import("std");

pub const Interval = extern struct {
    min: f32,
    max: f32,

    pub fn initFromIntervals(a: Interval, b: Interval) Interval {
        return .{
            .min = if (a.min <= b.min) a.min else b.min,
            .max = if (a.max >= b.max) a.max else b.max,
        };
    }

    pub fn empty() Interval {
        return .{ .min = std.math.inf(f32), .max = -std.math.inf(f32) };
    }
};
