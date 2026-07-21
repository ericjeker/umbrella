const std = @import("std");
// SDL3 interop comes from the named "sdl" module (build.zig wires it via
// addImport). Using a named import instead of "../sdl.zig" keeps this file
// reachable from any module root (e.g. the test in entities/) without
// tripping the "import outside module path" rule on relative escapes.
const sdl = @import("sdl").sdl;

const Vertex = struct { x: f32, y: f32 };

pub const Triangle = struct {
    cx: f32,
    cy: f32,
    size: f32,
    angle_deg: f32,

    // --- "constructor": a free function in the same file, returning Self ---
    // Zig has no `new`. A static-factory-style function is just a namespaced
    // function returning an instance. Idiomatic name is `init` (or `create`
    // if it allocates on the heap; this one is stack/value-sized).
    pub fn init(cx: f32, cy: f32, size: f32, angle_deg: f32) Triangle {
        return .{
            .cx = cx,
            .cy = cy,
            .size = size,
            .angle_deg = angle_deg,
        };
    }

    // --- behavior: methods are just functions whose first param is `self` ---
    // Method-call syntax (tri.rotate(1.0)) desugars to Triangle.rotate(tri, 1.0).
    // `self` is an ordinary named parameter; calling it `self` is convention.
    pub fn rotate(self: *Triangle, degrees: f32) void {
        self.angle_deg = @mod(self.angle_deg + degrees, 360.0);
    }

    pub fn draw(self: Triangle, renderer: ?*sdl.SDL_Renderer) void {
        const a = self.angle_deg * std.math.rad_per_deg;
        const verts: [3]Vertex = .{
            self.vertexAt(a, 0.0),
            self.vertexAt(a, 2.0 * std.math.pi / 3.0),
            self.vertexAt(a, 4.0 * std.math.pi / 3.0),
        };

        // SDL_RenderLines wants a flat array of SDL_FPoint.
        // Draw the three edges as a closed loop (4 points: p0→p1→p2→p0).
        var points: [4]sdl.SDL_FPoint = undefined;
        inline for (0..3) |i| {
            points[i] = .{ .x = verts[i].x, .y = verts[i].y };
        }
        points[3] = points[0];
        _ = sdl.SDL_SetRenderDrawColor(renderer, 220, 220, 255, 255);
        _ = sdl.SDL_RenderLines(renderer, &points, points.len);
    }

    // --- private helper: not pub, so only visible within this file ---
    // This is Zig's "private method": file-level visibility. Anything
    // outside entities/triangle.zig cannot call vertexAt, only Triangle's
    // pub functions. No `private` keyword needed.
    fn vertexAt(self: Triangle, base_angle: f32, offset: f32) Vertex {
        const ang = base_angle + offset;
        return .{
            .x = self.cx + self.size * @sin(ang),
            .y = self.cy - self.size * @cos(ang), // minus because y is down
        };
    }
};
