#ifndef ZEN_INTERVAL_METAL
#define ZEN_INTERVAL_METAL

#include <metal_stdlib>
using namespace metal;

struct Interval {
    float min;
    float max;

    Interval()
        : min(INFINITY), max(-INFINITY) {}

    Interval(float min_, float max_)
        : min(min_), max(max_) {}

    float size() const {
        return max - min;
    }

    bool contains(float x) const {
        return x >= min && x <= max;
    }

    bool surrounds(float x) const {
        return x > min && x < max;
    }

    static Interval empty() {
        return Interval(INFINITY, -INFINITY);
    }

    static Interval universe() {
        return Interval(-INFINITY, INFINITY);
    }
};

#endif
