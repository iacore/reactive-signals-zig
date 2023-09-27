const std = @import("std");
const signals = @import("signals");

test "type check" {
    std.testing.refAllDeclsRecursive(signals);
}

const Scope = signals.DependencyTracker;

fn get(cx: *Scope, id: u64) void {
    // std.log.warn("get({})", .{id});
    cx.used(id);
    if (id >= 4 and cx.setDirty(id, false)) {
        cx.begin(id);
        defer cx.end();
        const base = id - id % 4 - 4;
        switch (id % 4) {
            0 => {
                get(cx, base + 1);
            },
            1 => {
                get(cx, base + 0);
                get(cx, base + 2);
            },
            2 => {
                get(cx, base + 1);
                get(cx, base + 3);
            },
            3 => {
                get(cx, base + 2);
            },
            else => unreachable,
        }
    }
}

/// returns ns elapsed
fn run(layer_count: usize, comptime check: bool) !u64 {
    var opts = Scope.InitOptions{};
    opts.dependency_pairs_capacity *= @max(1, layer_count / 100);
    opts.dependent_stack_capacity *= @max(1, layer_count / 100);
    opts.dirty_set_capacity *= @max(1, @as(u32, @intCast(layer_count / 100)));
    var cx = try Scope.init(std.testing.allocator, opts);
    defer cx.deinit();

    const base_id = (layer_count - 1) * 4;

    var timer = try std.time.Timer.start();

    for (0..layer_count * 4) |i| {
        _ = cx.setDirty(i, true);
    }

    const ns_prepare = timer.lap();

    get(&cx, base_id + 0);
    get(&cx, base_id + 1);
    get(&cx, base_id + 2);
    get(&cx, base_id + 3);

    if (check) for (0..layer_count * 4) |i| {
        try std.testing.expect(!cx.isDirty(i));
    };

    const ns0 = timer.lap();

    get(&cx, base_id + 0);
    get(&cx, base_id + 1);
    get(&cx, base_id + 2);
    get(&cx, base_id + 3);

    if (check) for (0..layer_count * 4) |i| {
        try std.testing.expect(!cx.isDirty(i));
    };

    const ns1 = timer.lap();

    cx.invalidate(0);
    cx.invalidate(1);
    cx.invalidate(2);
    cx.invalidate(3);

    if (check) {
        {
            var it = cx.dirty_map.iterator();
            while (it.next()) |kv| {
                std.log.warn("dirty: {}", .{kv.key_ptr.*});
            }
        }
        {
            for (cx.pairs.items) |kv| {
                std.log.warn("dep: {} -> {}", .{ kv[0], kv[1] });
            }
        }

        for (0..4) |i| {
            try std.testing.expect(!cx.isDirty(i));
        }
        for (4..layer_count * 4) |i| {
            try std.testing.expect(cx.isDirty(i));
        }
    }

    const ns2 = timer.lap();

    get(&cx, base_id + 0);
    get(&cx, base_id + 1);
    get(&cx, base_id + 2);
    get(&cx, base_id + 3);

    if (check) for (0..layer_count * 4) |i| {
        try std.testing.expect(!cx.isDirty(i));
    };

    const ns3 = timer.lap();

    get(&cx, base_id + 0);
    get(&cx, base_id + 1);
    get(&cx, base_id + 2);
    get(&cx, base_id + 3);

    if (check) for (0..layer_count * 4) |i| {
        try std.testing.expect(!cx.isDirty(i));
    };

    const ns4 = timer.lap();

    // std.log.warn("time used: {any}", .{[_]u64{ ns_start, ns0, ns1, ns2, ns3, ns4 }});

    return ns_prepare + ns0 + ns1 + ns2 + ns3 + ns4;
}

const RUNS_PER_TIER = 150;
const LAYER_TIERS = [_]usize{
    10,
    100,
    500,
    1000,
    2000,
};

test "bench" {
    for (LAYER_TIERS) |n_layers| {
        var sum: u64 = 0;
        for (0..RUNS_PER_TIER) |_| {
            sum += try run(n_layers, false);
        }
        const ns: f64 = @floatFromInt(sum / RUNS_PER_TIER);
        const ms = ns / std.time.ns_per_ms;
        std.log.warn("n_layers={} avg {d}ms", .{ n_layers, ms });
    }
}

test "sanity check" {
    try run(2, true);
}

// const SOLUTIONS = {
//   10: [2, 4, -2, -3],
//   100: [-2, -4, 2, 3],
//   500: [-2, 1, -4, -4],
//   1000: [-2, -4, 2, 3],
//   2000: [-2, 1, -4, -4],
//   // 2500: [-2, -4, 2, 3],
// };
