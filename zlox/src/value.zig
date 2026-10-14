const std = @import("std");

const array = @import("lib::array.zig");
const utils = @import("lib::utils.zig");
const NaNBox = @import("lib::nanbox.zig").NaNBox;

const Obj = @import("gc.zig").GC.Obj;

pub const Value = NanBoxValue;

pub const UnionValue = union(enum) {
    number: f64,
    char: u8,
    bool: bool,
    nil: void,
    obj: *Obj,

    const Self = @This();
    pub const Tag = std.meta.Tag(Self);

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        switch (self) {
            .number => |val| try writer.print("{d}", .{val}),
            .char => |val| try writer.writeAll(&[_]u8{val}),
            .bool => |val| try writer.writeAll(if (val) "true" else "false"),
            .nil => try writer.writeAll("nil"),
            .obj => |o| switch (o.type) {
                inline else => |tp| if (@hasDecl(tp.get(), "format"))
                    try (o.cast(tp) catch unreachable).format(writer)
                else
                    try o.format(writer),
            },
        }
    }

    fn tagNameOf(T: type) []const u8 {
        return @tagName(utils.tagFromType(Self, T));
    }

    pub fn typeName(self: Self) []const u8 {
        return switch (self) {
            .obj => |o| @tagName(o.type),
            inline else => |tp| tagNameOf(@TypeOf(tp)),
        };
    }

    pub fn init(val: anytype) Self {
        return @unionInit(Self, tagNameOf(@TypeOf(val)), val);
    }

    fn toTag(comptime from: anytype) Tag {
        return if (@TypeOf(from) == Obj.Type)
            .obj
        else
            from;
    }

    pub fn is(self: Self, comptime tag: anytype) bool {
        return switch (self) {
            toTag(tag) => @TypeOf(tag) != Obj.Type or self.obj.is(tag),
            else => false,
        };
    }

    pub fn cast_if(self: Self, comptime tag: anytype) if (@TypeOf(tag) == Obj.Type) ?*Obj.Type.get(tag) else ?utils.typeFromTag(Self, tag) {
        return switch (self) {
            toTag(tag) => if (@TypeOf(tag) == Obj.Type) self.obj.cast_if(tag) else self.get(tag),
            else => null,
        };
    }

    pub fn get(self: Self, comptime tag: anytype) tagType(tag) {
        return @field(self, @tagName(toTag(tag)));
    }

    pub fn tagType(comptime tag: anytype) type {
        return utils.typeFromTag(Self, toTag(tag));
    }

    pub fn parseNumber(str: []const u8) !Self {
        return Self{ .number = try std.fmt.parseFloat(tagType(Value.number), str) };
    }

    pub fn isTruthy(self: Self) bool {
        return switch (self) {
            .nil => false,
            .bool => |val| val,
            else => true,
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        if (@intFromEnum(self) != @intFromEnum(other)) return false;
        return switch (self) {
            .number => |x| x == other.number,
            .char => |x| x == other.char,
            .bool => |x| x == other.bool,
            .nil => true,
            .obj => |x| x.eql(other.obj),
        };
    }
};

pub const NanBoxValue = struct {
    const Box = NaNBox(.{
        .number = f64,
        .char = u8,
        .bool = bool,
        .nil = void,
        .obj = *Obj,
    });

    box: Box,

    const Self = @This();
    pub const Tag = Box.Type;

    pub fn format(self: Self, writer: *std.Io.Writer) !void {
        if (self.box.to(.number)) |val|
            try writer.print("{d}", .{val})
        else if (self.box.to(.char)) |val|
            try writer.writeAll(&[_]u8{val})
        else if (self.box.to(.bool)) |val|
            try writer.writeAll(if (val) "true" else "false")
        else if (self.box.is(.nil))
            try writer.writeAll("nil")
        else if (self.box.to(.obj)) |o|
            switch (o.type) {
                inline else => |tp| if (@hasDecl(tp.get(), "format"))
                    try (o.cast(tp) catch unreachable).format(writer)
                else
                    try o.format(writer),
            };
    }

    pub fn typeName(self: Self) []const u8 {
        if (self.box.to(.obj)) |o|
            return @tagName(o.type);

        inline for (std.enums.values(Box.Type)) |tag|
            if (self.box.is(tag))
                return @tagName(tag);

        unreachable;
    }

    pub fn init(val: anytype) Self {
        inline for (std.enums.values(Box.Type)) |tag|
            if (comptime Box.typeof(tag) == @TypeOf(val))
                return .{ .box = Box.of(tag, val) };

        @compileError("No matching tag for type " ++ @typeName(@TypeOf(val)) ++ " in Value");
    }

    pub fn is(self: Self, comptime tag: anytype) bool {
        const T = @TypeOf(tag);

        return if (T == Tag or T == @EnumLiteral())
            self.box.is(tag)
        else if (self.box.to(.obj)) |o|
            o.is(tag)
        else
            false;
    }

    pub fn Casted(comptime tag: anytype) type {
        const T = @TypeOf(tag);

        return if (T == Tag or T == @EnumLiteral())
            Box.typeof(tag)
        else if (T == Obj.Type)
            *Obj.Type.get(tag)
        else
            @compileError("Invalid tag: " ++ @tagName(tag));
    }

    pub fn cast_if(self: Self, comptime tag: anytype) ?Casted(tag) {
        const T = @TypeOf(tag);

        return if (T == Tag or T == @EnumLiteral())
            self.box.to(tag)
        else if (self.box.to(.obj)) |o|
            o.cast_if(tag)
        else
            null;
    }

    pub fn get(self: Self, comptime tag: anytype) tagType(tag) {
        return self.box.to(toTag(tag)).?;
    }

    fn toTag(comptime tag: anytype) Tag {
        return if (@TypeOf(tag) == Obj.Type)
            Box.Type.obj
        else
            tag;
    }

    pub fn tagType(comptime tag: anytype) type {
        return Box.typeof(toTag(tag));
    }

    pub fn parseNumber(str: []const u8) !Self {
        return Self{ .box = Box.of(.number, try std.fmt.parseFloat(Box.typeof(.number), str)) };
    }

    pub fn isTruthy(self: Self) bool {
        return if (self.box.is(.nil))
            false
        else if (self.box.to(.bool)) |val|
            val
        else
            true;
    }

    pub fn eql(self: Self, other: Self) bool {
        return if (self.box.to(.obj)) |o|
            o.eql(other.box.to(.obj) orelse return false)
        else
            self.box.value == other.box.value;
    }
};
