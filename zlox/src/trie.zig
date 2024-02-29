const std = @import("std");

pub fn TrieTable(comptime T: type, comptime list: anytype) type {
    const TrieLeaf = struct {
        value: ?T,
        data: [26]?*@This(),
    };

    const max_len = comptime blk: {
        var ret = 0;
        for (list) |el| {
            ret += el.@"0".len;
        }
        break :blk ret;
    };

    const precomputed = comptime blk: {
        var allocated = [_]TrieLeaf{TrieLeaf{ .value = null, .data = [_]?*TrieLeaf{null} ** 26 }} ** max_len;
        var allocated_i = 0;
        var tip = TrieLeaf{ .value = null, .data = [_]?*TrieLeaf{null} ** 26 };

        for (list) |el| {
            var leaf = &tip;
            for (el.@"0") |ch| {
                const idx = ch - 'a';
                if (leaf.data[idx]) |val| {
                    leaf = val;
                } else {
                    var new = &allocated[allocated_i];
                    allocated_i += 1;
                    new.value = null;
                    new.data = [_]?*TrieLeaf{null} ** 26;
                    leaf.data[idx] = new;
                    leaf = new;
                }
            }
            leaf.value = el.@"1";
        }
        break :blk .{ .allocated = allocated, .tip = tip };
    };

    return struct {
        const allocated = precomputed.allocated;
        const tip = precomputed.tip;

        pub fn get(word: []const u8) ?T {
            var this = &tip;
            for (word) |ch| {
                if (ch < 'a' or ch > 'z') return null;
                const idx = ch - 'a';
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
