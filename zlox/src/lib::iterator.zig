const utils = @import("lib::utils.zig");

fn has_fn(Type: type, comptime field: []const u8) bool {
    return @hasDecl(Type, field) and utils.is_type(@TypeOf(@field(Type, field)), "fn");
}

fn is(comptime thing: anytype) ?@TypeOf(thing) {
    return if (@TypeOf(thing) == void) null else thing;
}

fn errorout(Type: type, Mod: type, comptime field: []const u8) if (has_fn(Mod, field)) @TypeOf(@field(Mod, field)) else fn (Type) noreturn {
    return if (has_fn(Mod, field)) @field(Mod, field) else struct {
        pub fn fun(_: Type) noreturn {
            @compileError("This iterator doesn't support this method");
        }
    }.fun;
}

pub fn Iterator(_Type: type, Mod: type) type {
    return struct {
        const Self = @This();
        pub const Type = _Type;

        const _get = if (has_fn(Mod, "get")) Mod.get;
        const _next = errorout(Type, Mod, "next");
        const _prev = errorout(Type, Mod, "prev");

        pub const Return = if (is(_get)) |get| utils.fn_return(get).? else Type;

        cur: ?Type = null,
        end: ?Type = null,

        fn proceed(call: fn (Self.Type) Self.Type) fn (*Self) ?Self.Return {
            return struct {
                pub fn lmbd(self: *Self) ?Self.Return {
                    if (self.cur) |cur| {
                        self.cur = if (cur == self.end)
                            null
                        else
                            call(cur);
                        return if (comptime is(_get)) |get| get(cur) else cur;
                    }
                    return null;
                }
            }.lmbd;
        }

        pub const next = proceed(_next);
        pub const prev = proceed(_prev);

        pub const rev = struct {
            pub fn rev(self: *const Self) Iterator(Type, struct {
                pub const next = _prev;
                pub const prev = _next;
                pub const get = _get;
            }) {
                return .{ .cur = self.end, .end = self.cur };
            }
        }.rev;

        pub fn stop(self: *Self) void {
            self.cur = null;
            self.end = null;
        }
    };
}

pub fn Slice(Type: type) type {
    const Ptr = utils.with_size(Type, .many);
    return Iterator(Ptr, struct {
        pub fn next(p: Ptr) Ptr {
            return p + 1;
        }
        pub fn prev(p: Ptr) Ptr {
            return p - 1;
        }
        pub fn get(p: Ptr) Type {
            return p.*;
        }
    });
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

pub fn Range(Type: type) type {
    return Iterator(Type, struct {
        pub fn next(t: Type) Type {
            return t + 1;
        }
        pub fn prev(p: Type) Type {
            return p - 1;
        }
    });
}

pub fn range(from: anytype, to: @TypeOf(from)) Range(@TypeOf(from)) {
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
        lhs: ?Lhs.Return,
        rhs: ?Lhs.Return,
    } {
        @setEvalBranchQuota(2_000);
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
        lhs: Rhs.Return,
        rhs: Lhs.Return,
    } {
        @setEvalBranchQuota(2_000);
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
