pub fn Trie(comptime T: type) type {
    return struct {
        len: S,
        data: []T,
        allocator: std.mem.Allocator,
