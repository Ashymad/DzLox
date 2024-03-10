const std = @import("std");

pub fn TrieTable(comptime Key: type, comptime Value: type, size: comptime_int, get_idx: fn (Key) usize, comptime list: anytype) type {
    const TrieLeaf = struct {
        value: ?Value,
        data: [size]?*@This(),
    };

    const max_len = comptime blk: {
        var ret = 0;
        for (list) |el| {
            ret += el.@"0".len;
        }
        break :blk ret;
    };

    const precomputed = comptime blk: {
        var allocated = [_]TrieLeaf{TrieLeaf{ .value = null, .data = [_]?*TrieLeaf{null} ** size }} ** max_len;
        var allocated_i = 0;
        var tip = TrieLeaf{ .value = null, .data = [_]?*TrieLeaf{null} ** size };

        for (list) |el| {
            var leaf = &tip;
            for (el.@"0") |key| {
                const idx = get_idx(key);
                std.debug.assert(idx >= 0 and idx < size);
                if (leaf.data[idx]) |val| {
                    leaf = val;
                } else {
                    var new = &allocated[allocated_i];
                    allocated_i += 1;
                    new.value = null;
                    new.data = [_]?*TrieLeaf{null} ** size;
                    leaf.data[idx] = new;
                    leaf = new;
                }
            }
            leaf.value = el.@"1";
        }
        break :blk .{ .allocated = allocated[0..allocated_i], .tip = tip };
    };

    return struct {
        const allocated = precomputed.allocated;
        const tip = precomputed.tip;

        pub fn get(word: []const Key) ?Value {
            var this = &tip;
            for (word) |key| {
                const idx = get_idx(key);
                if (idx < 0 or idx >= size) return null;
                if (this.data[idx]) |val| {
                    this = val;
                } else {
                    return null;
                }
            }
            return this.value;
        }
    };
}

pub fn LowercaseTrieTable(comptime Value: type, comptime list: anytype) type {
    return TrieTable(u8, Value, 26, struct {
        pub fn idx(c: u8) usize {
            return c - 'a';
        }
    }.idx, list);
}
