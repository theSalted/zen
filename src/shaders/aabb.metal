#include "interval.metal"
#include "ray.metal"

struct AABB {
    Interval x, y, z;

    AABB() {};

    AABB(Interval x, Interval y, Interval z): x(x), y(y), z(z) {};

    AABB(float3 a, float3 b) {
        x = (a[0] <= b[0]) ? Interval(a[0], b[0]) : Interval(b[0], a[0]);
        y = (a[1] <= b[1]) ? Interval(a[1], b[1]) : Interval(b[1], a[1]);
        z = (a[2] <= b[2]) ? Interval(a[2], b[2]) : Interval(b[2], a[2]);
    };

    Interval axis_interval(uint n) const {
        if (n == 1) return y;
        if (n == 2) return z;
        return x;
    }

    bool hit(thread const Ray& r, Interval ray_t) const {
        const float3 origin = r.origin;
        const float3 direction = r.direction;

        for (int axis = 0; axis < 3; axis++) {
            const Interval ax = axis_interval(axis);
            const float adinv = 1.0 / direction[axis];

            auto t0 = (ax.min - origin[axis]) * adinv;
            auto t1 = (ax.max - origin[axis]) * adinv;

            if (t0 < t1) {
                if (t0 > ray_t.min) ray_t.min = t0;
                if (t1 < ray_t.max) ray_t.max = t1;
            } else {
                if (t1 > ray_t.min) ray_t.min = t1;
                if (t0 < ray_t.max) ray_t.max = t0;
            }

            if (ray_t.max <= ray_t.min)
                return false;
        }
        return true;
    }
};
