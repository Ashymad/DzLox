const utils = @import("lib::utils.zig");

pub fn Iterator(Type: type) type {
    return struct {
        const Self = @This();

        cur: ?Type = null,
        end: ?Type = null,
        fwd: bool = true,

        pub fn next(self: *Self) ?Type {
            if (self.cur) |cur| {
                self.cur = if (cur == self.end)
                    null
                else if (self.fwd)
                    cur + 1
                else
                    cur - 1;
                return cur;
            }
            return null;
        }

        pub fn reverse(self: *const Self) Self {
            return .{
                .cur = self.end,
                .end = self.cur,
                .fwd = !self.fwd,
            };
        }

        pub fn finish(self: *Self) void {
            self.cur = null;
            self.end = null;
        }
    };
}

pub fn Slice(Type: type) type {
    return Iterator(utils.with_size(Type, .many));
}

pub fn slice(val: anytype) Slice(@TypeOf(val)) {
    const Type = @TypeOf(val);

    if (!utils.is_type(Type, "pointer") or @typeInfo(Type).pointer.size != .slice)
        @compileError("The iterator argument needs to be a slice");

    return if (val.len == 0)
        .{}
    else
        .{
            .cur = &val[0],
            .end = &val[val.len - 1],
        };
}

pub fn range(from: anytype, to: @TypeOf(from)) Iterator(@TypeOf(from)) {
    return if (to <= from)
        .{}
    else
        .{
            .cur = from,
            .end = to - 1,
        };
}

pub fn zip_longest(lhs: anytype, rhs: anytype) struct {
    const Self = @This();
    const Lhs = @TypeOf(lhs);
    const Rhs = @TypeOf(rhs);

    lhs: Lhs,
    rhs: Rhs,

    pub fn next(self: *Self) ?struct {
        lhs: utils.fn_return(Lhs.next).?,
        rhs: utils.fn_return(Rhs.next).?,
    } {
        const lhsn = self.lhs.next();
        const rhsn = self.rhs.next();
        return if (lhsn == null and rhsn == null)
            null
        else
            .{ .lhs = lhsn, .rhs = rhsn };
    }
} {
    return .{ .lhs = lhs, .rhs = rhs };
}

pub fn zip(lhs: anytype, rhs: anytype) struct {
    const Self = @This();
    const Lhs = @TypeOf(lhs);
    const Rhs = @TypeOf(rhs);

    lhs: Lhs,
    rhs: Rhs,

    pub fn next(self: *Self) ?struct {
        lhs: utils.fn_return(Lhs.next).?.optional.child,
        rhs: utils.fn_return(Rhs.next).?.optional.child,
    } {
        if (self.lhs.next()) |lhsn|
            if (self.rhs.next()) |rhsn|
                return .{ .lhs = lhsn, .rhs = rhsn }
            else
                null
        else
            null;
    }
} {
    return .{ .lhs = lhs, .rhs = rhs };
}
