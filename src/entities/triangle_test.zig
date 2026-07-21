const std = @import("std");
const Triangle = @import("triangle.zig").Triangle;

test "init sets all fields" {
    const t = Triangle.init(400.0, 300.0, 120.0, 45.0);
    try std.testing.expectEqual(400.0, t.cx);
    try std.testing.expectEqual(300.0, t.cy);
    try std.testing.expectEqual(120.0, t.size);
    try std.testing.expectEqual(45.0, t.angle_deg);
}

test "rotate increments angle by the given amount" {
    var t = Triangle.init(0.0, 0.0, 10.0, 0.0);
    t.rotate(1.0);
    try std.testing.expectEqual(1.0, t.angle_deg);
    t.rotate(1.0);
    try std.testing.expectEqual(2.0, t.angle_deg);
    t.rotate(17.5);
    try std.testing.expectEqual(19.5, t.angle_deg);
}

test "rotate wraps from 360 back to 0" {
    var t = Triangle.init(0.0, 0.0, 10.0, 359.0);
    t.rotate(1.0);
    try std.testing.expectEqual(0.0, t.angle_deg);
}

test "rotate wraps on negative increments" {
    // Zig @mod follows the sign of the DIVISOR (360 > 0), so -10 mod 360
    // is 350, not -10. This is Python-style modulo, not C-style fmod.
    var t = Triangle.init(0.0, 0.0, 10.0, 0.0);
    t.rotate(-10.0);
    try std.testing.expectEqual(350.0, t.angle_deg);
}

test "a full 360-degree rotation returns to the starting angle" {
    // 360 successive rotate(1.0) calls. Float error accumulates slightly
    // through repeated add + @mod, so use an approximate comparison.
    var t = Triangle.init(0.0, 0.0, 10.0, 42.0);
    var i: usize = 0;
    while (i < 360) : (i += 1) {
        t.rotate(1.0);
    }
    try std.testing.expectApproxEqAbs(42.0, t.angle_deg, 1e-4);
}

test "rotate never produces a value outside [0, 360)" {
    var t = Triangle.init(0.0, 0.0, 10.0, 90.0);
    const steps = [_]f32{ 1.0, -5.0, 200.0, -1000.0, 7.25, 720.0, -360.0 };
    for (steps) |s| {
        t.rotate(s);
        try std.testing.expect(t.angle_deg >= 0.0);
        try std.testing.expect(t.angle_deg < 360.0);
    }
}
