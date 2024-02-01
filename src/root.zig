const std = @import("std");
const builtin = @import("builtin");
const zwav = @import("zwav.zig");

comptime {
    if (builtin.is_test) {
        _ = std.testing.refAllDeclsRecursive(zwav);
    }
}
