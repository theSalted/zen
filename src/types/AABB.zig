const common = @import("../common.zig");
const Interval = @import("Interval.zig").Interval;

pub const AABB = extern struct {
    x: Interval,
    y: Interval,
    z: Interval,

    pub fn initFromPoints(a: common.Vector3, b: common.Vector3) AABB {
        return AABB{
            .x = (if (a[0] <= b[0]) Interval{ .min = a[0], .max = b[0] } else Interval{ .min = b[0], .max = a[0] }),
            .y = (if (a[1] <= b[1]) Interval{ .min = a[1], .max = b[1] } else Interval{ .min = b[1], .max = a[1] }),
            .z = (if (a[2] <= b[2]) Interval{ .min = a[2], .max = b[2] } else Interval{ .min = b[2], .max = a[2] }),
        };
    }

    pub fn initFromAABB(a: AABB, b: AABB) AABB {
        return AABB{
            .x = Interval.initFromIntervals(a.x, b.x),
            .y = Interval.initFromIntervals(a.y, b.y),
            .z = Interval.initFromIntervals(a.z, b.z),
        };
    }

    pub fn empty() AABB {
        return AABB{
            .x = Interval.empty(),
            .y = Interval.empty(),
            .z = Interval.empty(),
        };
    }
};
