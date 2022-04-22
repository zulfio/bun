const std = @import("std");
const expect = std.testing.expect;
const Environment = @import("./env.zig");
const string = @import("string_types.zig").string;
const stringZ = @import("string_types.zig").stringZ;
const CodePoint = @import("string_types.zig").CodePoint;
const assert = std.debug.assert;
pub inline fn containsChar(self: string, char: u8) bool {
    return indexOfChar(self, char) != null;
}

pub inline fn contains(self: string, str: string) bool {
    return std.mem.indexOf(u8, self, str) != null;
}
pub inline fn containsComptime(self: string, comptime str: string) bool {
    var remain = self;
    const Int = std.meta.Int(.unsigned, str.len * 8);

    while (remain.len >= comptime str.len) {
        if (@bitCast(Int, remain.ptr[0..str.len].*) == @bitCast(Int, str.ptr[0..str.len].*)) {
            return true;
        }
        remain = remain[str.len..];
    }

    return false;
}
pub const includes = contains;

pub inline fn containsAny(in: anytype, target: string) bool {
    for (in) |str| if (contains(str, target)) return true;
    return false;
}

pub inline fn indexAny(in: anytype, target: string) ?usize {
    for (in) |str, i| if (indexOf(str, target) != null) return i;
    return null;
}

pub inline fn indexAnyComptime(target: string, comptime chars: string) ?usize {
    for (target) |parent, i| {
        inline for (chars) |char| {
            if (char == parent) return i;
        }
    }
    return null;
}

pub fn repeatingAlloc(allocator: std.mem.Allocator, count: usize, char: u8) ![]u8 {
    var buf = try allocator.alloc(u8, count);
    repeatingBuf(buf, char);
    return buf;
}

pub fn repeatingBuf(self: []u8, char: u8) void {
    @memset(self.ptr, char, self.len);
}

pub fn indexOfCharNeg(self: string, char: u8) i32 {
    var i: u32 = 0;
    while (i < self.len) : (i += 1) {
        if (self[i] == char) return @intCast(i32, i);
    }
    return -1;
}

/// Format a string to an ECMAScript identifier.
/// Unlike the string_mutable.zig version, this always allocate/copy
pub fn fmtIdentifier(name: string) FormatValidIdentifier {
    return FormatValidIdentifier{ .name = name };
}

/// Format a string to an ECMAScript identifier.
/// Different implementation than string_mutable because string_mutable may avoid allocating
/// This will always allocate
pub const FormatValidIdentifier = struct {
    name: string,
    const js_lexer = @import("./js_lexer.zig");
    pub fn format(self: FormatValidIdentifier, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var iterator = strings.CodepointIterator.init(self.name);
        var cursor = strings.CodepointIterator.Cursor{};

        var has_needed_gap = false;
        var needs_gap = false;
        var start_i: usize = 0;

        if (!iterator.next(&cursor)) {
            try writer.writeAll("_");
            return;
        }

        // Common case: no gap necessary. No allocation necessary.
        needs_gap = !js_lexer.isIdentifierStart(cursor.c);
        if (!needs_gap) {
            // Are there any non-alphanumeric chars at all?
            while (iterator.next(&cursor)) {
                if (!js_lexer.isIdentifierContinue(cursor.c) or cursor.width > 1) {
                    needs_gap = true;
                    start_i = cursor.i;
                    break;
                }
            }
        }

        if (needs_gap) {
            needs_gap = false;

            var slice = self.name[start_i..];
            iterator = strings.CodepointIterator.init(slice);
            cursor = strings.CodepointIterator.Cursor{};

            while (iterator.next(&cursor)) {
                if (js_lexer.isIdentifierContinue(cursor.c) and cursor.width == 1) {
                    if (needs_gap) {
                        try writer.writeAll("_");
                        needs_gap = false;
                        has_needed_gap = true;
                    }
                    try writer.writeAll(slice[cursor.i .. cursor.i + @as(u32, cursor.width)]);
                } else if (!needs_gap) {
                    needs_gap = true;
                    // skip the code point, replace it with a single _
                }
            }

            // If it ends with an emoji
            if (needs_gap) {
                try writer.writeAll("_");
                needs_gap = false;
                has_needed_gap = true;
            }

            return;
        }

        try writer.writeAll(self.name);
    }
};

pub fn indexOfSigned(self: string, str: string) i32 {
    const i = std.mem.indexOf(u8, self, str) orelse return -1;
    return @intCast(i32, i);
}

pub inline fn lastIndexOfChar(self: string, char: u8) ?usize {
    return std.mem.lastIndexOfScalar(u8, self, char);
}

pub inline fn lastIndexOf(self: string, str: string) ?usize {
    return std.mem.lastIndexOf(u8, self, str);
}

pub inline fn indexOf(self: string, str: string) ?usize {
    return std.mem.indexOf(u8, self, str);
}

// --
// This is faster when the string is found, by about 2x for a 4 MB file.
// It is slower when the string is NOT found
// fn indexOfPosN(comptime T: type, buf: []const u8, start_index: usize, delimiter: []const u8, comptime n: comptime_int) ?usize {
//     const k = delimiter.len;
//     const V8x32 = @Vector(n, T);
//     const V1x32 = @Vector(n, u1);
//     const Vbx32 = @Vector(n, bool);
//     const first = @splat(n, delimiter[0]);
//     const last = @splat(n, delimiter[k - 1]);

//     var end: usize = start_index + n;
//     var start: usize = end - n;
//     while (end < buf.len) {
//         start = end - n;
//         const last_end = @minimum(end + k - 1, buf.len);
//         const last_start = last_end - n;

//         // Look for the first character in the delimter
//         const first_chunk: V8x32 = buf[start..end][0..n].*;
//         const last_chunk: V8x32 = buf[last_start..last_end][0..n].*;
//         const mask = @bitCast(V1x32, first == first_chunk) & @bitCast(V1x32, last == last_chunk);

//         if (@reduce(.Or, mask) != 0) {
//             // TODO: Use __builtin_clz???
//             for (@as([n]bool, @bitCast(Vbx32, mask))) |match, i| {
//                 if (match and eqlLong(buf[start + i .. start + i + k], delimiter, false)) {
//                     return start + i;
//                 }
//             }
//         }
//         end = @minimum(end + n, buf.len);
//     }
//     if (start < buf.len) return std.mem.indexOfPos(T, buf, start_index, delimiter);
//     return null; // Not found
// }

pub fn cat(allocator: std.mem.Allocator, first: string, second: string) !string {
    var out = try allocator.alloc(u8, first.len + second.len);
    std.mem.copy(u8, out, first);
    std.mem.copy(u8, out[first.len..], second);
    return out;
}

// 30 character string or a slice
pub const StringOrTinyString = struct {
    pub const Max = 30;
    const Buffer = [Max]u8;

    remainder_buf: Buffer = undefined,
    remainder_len: u7 = 0,
    is_tiny_string: u1 = 0,
    pub inline fn slice(this: *const StringOrTinyString) []const u8 {
        // This is a switch expression instead of a statement to make sure it uses the faster assembly
        return switch (this.is_tiny_string) {
            1 => this.remainder_buf[0..this.remainder_len],
            0 => @intToPtr([*]const u8, std.mem.readIntNative(usize, this.remainder_buf[0..@sizeOf(usize)]))[0..std.mem.readIntNative(usize, this.remainder_buf[@sizeOf(usize) .. @sizeOf(usize) * 2])],
        };
    }

    pub fn deinit(this: *StringOrTinyString, _: std.mem.Allocator) void {
        if (this.is_tiny_string == 1) return;

        // var slice_ = this.slice();
        // allocator.free(slice_);
    }

    pub fn initAppendIfNeeded(stringy: string, comptime Appender: type, appendy: Appender) !StringOrTinyString {
        if (stringy.len <= StringOrTinyString.Max) {
            return StringOrTinyString.init(stringy);
        }

        return StringOrTinyString.init(try appendy.append(string, stringy));
    }

    pub fn init(stringy: string) StringOrTinyString {
        switch (stringy.len) {
            0 => {
                return StringOrTinyString{ .is_tiny_string = 1, .remainder_len = 0 };
            },
            1...(@sizeOf(Buffer)) => {
                @setRuntimeSafety(false);
                var tiny = StringOrTinyString{
                    .is_tiny_string = 1,
                    .remainder_len = @truncate(u7, stringy.len),
                };
                @memcpy(&tiny.remainder_buf, stringy.ptr, tiny.remainder_len);
                return tiny;
            },
            else => {
                var tiny = StringOrTinyString{
                    .is_tiny_string = 0,
                    .remainder_len = 0,
                };
                std.mem.writeIntNative(usize, tiny.remainder_buf[0..@sizeOf(usize)], @ptrToInt(stringy.ptr));
                std.mem.writeIntNative(usize, tiny.remainder_buf[@sizeOf(usize) .. @sizeOf(usize) * 2], stringy.len);
                return tiny;
            },
        }
    }

    pub fn initLowerCase(stringy: string) StringOrTinyString {
        switch (stringy.len) {
            0 => {
                return StringOrTinyString{ .is_tiny_string = 1, .remainder_len = 0 };
            },
            1...(@sizeOf(Buffer)) => {
                @setRuntimeSafety(false);
                var tiny = StringOrTinyString{
                    .is_tiny_string = 1,
                    .remainder_len = @truncate(u7, stringy.len),
                };
                _ = copyLowercase(stringy, &tiny.remainder_buf);
                return tiny;
            },
            else => {
                var tiny = StringOrTinyString{
                    .is_tiny_string = 0,
                    .remainder_len = 0,
                };
                std.mem.writeIntNative(usize, tiny.remainder_buf[0..@sizeOf(usize)], @ptrToInt(stringy.ptr));
                std.mem.writeIntNative(usize, tiny.remainder_buf[@sizeOf(usize) .. @sizeOf(usize) * 2], stringy.len);
                return tiny;
            },
        }
    }
};

pub fn copyLowercase(in: string, out: []u8) string {
    var in_slice: string = in;
    var out_slice: []u8 = out[0..in.len];

    begin: while (out_slice.len > 0) {
        for (in_slice) |c, i| {
            switch (c) {
                'A'...'Z' => {
                    @memcpy(out_slice.ptr, in_slice.ptr, i);
                    out_slice[i] = std.ascii.toLower(c);
                    const end = i + 1;
                    if (end >= out_slice.len) break :begin;
                    in_slice = in_slice[end..];
                    out_slice = out_slice[end..];
                    continue :begin;
                },
                else => {},
            }
        }

        @memcpy(out_slice.ptr, in_slice.ptr, in_slice.len);
        break :begin;
    }

    return out[0..in.len];
}

test "indexOf" {
    const fixtures = .{
        .{
            "0123456789",
            "456",
        },
        .{
            "/foo/bar/baz/bacon/eggs/lettuce/tomatoe",
            "bacon",
        },
        .{
            "/foo/bar/baz/bacon////eggs/lettuce/tomatoe",
            "eggs",
        },
        .{
            "////////////////zfoo/bar/baz/bacon/eggs/lettuce/tomatoe",
            "/",
        },
        .{
            "/okay/well/thats/even/longer/now/well/thats/even/longer/now/well/thats/even/longer/now/foo/bar/baz/bacon/eggs/lettuce/tomatoe",
            "/tomatoe",
        },
        .{
            "/okay///////////so much length i can't believe it!much length i can't believe it!much length i can't believe it!much length i can't believe it!much length i can't believe it!much length i can't believe it!much length i can't believe it!much length i can't believe it!/well/thats/even/longer/now/well/thats/even/longer/now/well/thats/even/longer/now/foo/bar/baz/bacon/eggs/lettuce/tomatoe",
            "/tomatoe",
        },
    };

    inline for (fixtures) |pair| {
        try std.testing.expectEqual(
            indexOf(pair[0], pair[1]).?,
            std.mem.indexOf(u8, pair[0], pair[1]).?,
        );
    }
}

test "eqlComptimeCheckLen" {
    try std.testing.expectEqual(eqlComptime("bun-darwin-aarch64.zip", "bun-darwin-aarch64.zip"), true);
    const sizes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 23, 22, 24 };
    inline for (sizes) |size| {
        var buf: [size]u8 = undefined;
        std.mem.set(u8, &buf, 'a');
        var buf_copy: [size]u8 = undefined;
        std.mem.set(u8, &buf_copy, 'a');

        var bad: [size]u8 = undefined;
        std.mem.set(u8, &bad, 'b');
        try std.testing.expectEqual(std.mem.eql(u8, &buf, &buf_copy), eqlComptime(&buf, comptime brk: {
            var buf_copy_: [size]u8 = undefined;
            std.mem.set(u8, &buf_copy_, 'a');
            break :brk buf_copy_;
        }));

        try std.testing.expectEqual(std.mem.eql(u8, &buf, &bad), eqlComptime(&bad, comptime brk: {
            var buf_copy_: [size]u8 = undefined;
            std.mem.set(u8, &buf_copy_, 'a');
            break :brk buf_copy_;
        }));
    }
}

test "eqlComptimeUTF16" {
    try std.testing.expectEqual(eqlComptimeUTF16(std.unicode.utf8ToUtf16LeStringLiteral("bun-darwin-aarch64.zip"), "bun-darwin-aarch64.zip"), true);
    const sizes = [_]u16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 23, 22, 24 };
    inline for (sizes) |size| {
        var buf: [size]u16 = undefined;
        std.mem.set(u16, &buf, @as(u8, 'a'));
        var buf_copy: [size]u16 = undefined;
        std.mem.set(u16, &buf_copy, @as(u8, 'a'));

        var bad: [size]u16 = undefined;
        std.mem.set(u16, &bad, @as(u16, 'b'));
        try std.testing.expectEqual(std.mem.eql(u16, &buf, &buf_copy), eqlComptimeUTF16(&buf, comptime &brk: {
            var buf_copy_: [size]u8 = undefined;
            std.mem.set(u8, &buf_copy_, @as(u8, 'a'));
            break :brk buf_copy_;
        }));

        try std.testing.expectEqual(std.mem.eql(u16, &buf, &bad), eqlComptimeUTF16(&bad, comptime &brk: {
            var buf_copy_: [size]u8 = undefined;
            std.mem.set(u8, &buf_copy_, @as(u8, 'a'));
            break :brk buf_copy_;
        }));
    }
}

test "copyLowercase" {
    {
        var in = "Hello, World!";
        var out = std.mem.zeroes([in.len]u8);
        var out_ = copyLowercase(in, &out);
        try std.testing.expectEqualStrings(out_, "hello, world!");
    }

    {
        var in = "_ListCache";
        var out = std.mem.zeroes([in.len]u8);
        var out_ = copyLowercase(in, &out);
        try std.testing.expectEqualStrings(out_, "_listcache");
    }
}

test "StringOrTinyString" {
    const correct: string = "helloooooooo";
    const big = "wawaweewaverylargeihaveachairwawaweewaverylargeihaveachairwawaweewaverylargeihaveachairwawaweewaverylargeihaveachair";
    var str = StringOrTinyString.init(correct);
    try std.testing.expectEqualStrings(correct, str.slice());

    str = StringOrTinyString.init(big);
    try std.testing.expectEqualStrings(big, str.slice());
    try std.testing.expect(@sizeOf(StringOrTinyString) == 32);
}

test "StringOrTinyString Lowercase" {
    const correct: string = "HELLO!!!!!";
    var str = StringOrTinyString.initLowerCase(correct);
    try std.testing.expectEqualStrings("hello!!!!!", str.slice());
}

/// startsWith except it checks for non-empty strings
pub fn hasPrefix(self: string, str: string) bool {
    return str.len > 0 and startsWith(self, str);
}

pub fn startsWith(self: string, str: string) bool {
    if (str.len > self.len) {
        return false;
    }

    var i: usize = 0;
    while (i < str.len) {
        if (str[i] != self[i]) {
            return false;
        }
        i += 1;
    }

    return true;
}

pub inline fn endsWith(self: string, str: string) bool {
    return str.len == 0 or @call(.{ .modifier = .always_inline }, std.mem.endsWith, .{ u8, self, str });
}

pub inline fn endsWithComptime(self: string, comptime str: anytype) bool {
    return self.len >= str.len and eqlComptimeIgnoreLen(self[self.len - str.len .. self.len], comptime str);
}

pub inline fn startsWithChar(self: string, char: u8) bool {
    return self.len > 0 and self[0] == char;
}

pub inline fn endsWithChar(self: string, char: u8) bool {
    return self.len == 0 or self[self.len - 1] == char;
}

pub fn withoutTrailingSlash(this: string) []const u8 {
    var href = this;
    while (href.len > 1 and href[href.len - 1] == '/') {
        href = href[0 .. href.len - 1];
    }

    return href;
}

pub fn withoutLeadingSlash(this: string) []const u8 {
    return std.mem.trimLeft(u8, this, "/");
}

pub fn endsWithAny(self: string, str: string) bool {
    const end = self[self.len - 1];
    for (str) |char| {
        if (char == end) {
            return true;
        }
    }

    return false;
}

pub fn quotedAlloc(allocator: std.mem.Allocator, self: string) !string {
    var count: usize = 0;
    for (self) |char| {
        count += @boolToInt(char == '"');
    }

    if (count == 0) {
        return allocator.dupe(u8, self);
    }

    var i: usize = 0;
    var out = try allocator.alloc(u8, self.len + count);
    for (self) |char| {
        if (char == '"') {
            out[i] = '\\';
            i += 1;
        }
        out[i] = char;
        i += 1;
    }

    return out;
}

pub fn eqlAnyComptime(self: string, comptime list: []const string) bool {
    inline for (list) |item| {
        if (eqlComptimeCheckLenWithType(u8, self, item, true)) return true;
    }

    return false;
}

/// Count the occurences of a character in an ASCII byte array
/// uses SIMD
pub fn countChar(self: string, char: u8) usize {
    var total: usize = 0;
    var remaining = self;

    const splatted: AsciiVector = @splat(ascii_vector_size, char);

    while (remaining.len >= 16) {
        const vec: AsciiVector = remaining[0..ascii_vector_size].*;
        const cmp = @popCount(std.meta.Int(.unsigned, ascii_vector_size), @bitCast(@Vector(ascii_vector_size, u1), vec == splatted));
        total += @as(usize, @reduce(.Add, cmp));
        remaining = remaining[ascii_vector_size..];
    }

    while (remaining.len > 0) {
        total += @as(usize, @boolToInt(remaining[0] == char));
        remaining = remaining[1..];
    }

    return total;
}

test "countChar" {
    try std.testing.expectEqual(countChar("hello there", ' '), 1);
    try std.testing.expectEqual(countChar("hello;;;there", ';'), 3);
    try std.testing.expectEqual(countChar("hello there", 'z'), 0);
    try std.testing.expectEqual(countChar("hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there ", ' '), 28);
    try std.testing.expectEqual(countChar("hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there ", 'z'), 0);
    try std.testing.expectEqual(countChar("hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there hello there", ' '), 27);
}

pub fn endsWithAnyComptime(self: string, comptime str: string) bool {
    if (comptime str.len < 10) {
        const last = self[self.len - 1];
        inline for (str) |char| {
            if (char == last) {
                return true;
            }
        }

        return false;
    } else {
        return endsWithAny(self, str);
    }
}

pub fn eql(self: string, other: anytype) bool {
    if (self.len != other.len) return false;
    if (comptime @TypeOf(other) == *string) {
        return eql(self, other.*);
    }

    for (self) |c, i| {
        if (other[i] != c) return false;
    }
    return true;
}

pub inline fn eqlInsensitive(self: string, other: anytype) bool {
    return std.ascii.eqlIgnoreCase(self, other);
}

pub fn eqlComptime(self: string, comptime alt: anytype) bool {
    return eqlComptimeCheckLenWithType(u8, self, alt, true);
}

pub fn eqlComptimeUTF16(self: []const u16, comptime alt: []const u8) bool {
    return eqlComptimeCheckLenWithType(u16, self, comptime std.unicode.utf8ToUtf16LeStringLiteral(alt), true);
}

pub fn eqlComptimeIgnoreLen(self: string, comptime alt: anytype) bool {
    return eqlComptimeCheckLenWithType(u8, self, alt, false);
}

pub inline fn eqlComptimeCheckLenWithType(comptime Type: type, a: []const Type, comptime b: anytype, comptime check_len: bool) bool {
    @setEvalBranchQuota(9999);
    if (comptime check_len) {
        if (comptime b.len == 0) {
            return a.len == 0;
        }

        switch (a.len) {
            b.len => {},
            else => return false,
        }
    }

    const len = comptime b.len;
    comptime var dword_length = b.len >> 3;
    const slice = comptime if (@typeInfo(@TypeOf(b)) != .Pointer) b else std.mem.span(b);
    const divisor = comptime @sizeOf(Type);

    comptime var b_ptr: usize = 0;

    inline while (dword_length > 0) : (dword_length -= 1) {
        if (@bitCast(usize, a[b_ptr..][0 .. @sizeOf(usize) / divisor].*) != comptime @bitCast(usize, (slice[b_ptr..])[0 .. @sizeOf(usize) / divisor].*))
            return false;
        comptime b_ptr += @sizeOf(usize);
        if (comptime b_ptr == b.len) return true;
    }

    if (comptime @sizeOf(usize) == 8) {
        if (comptime (len & 4) != 0) {
            if (@bitCast(u32, a[b_ptr..][0 .. @sizeOf(u32) / divisor].*) != comptime @bitCast(u32, (slice[b_ptr..])[0 .. @sizeOf(u32) / divisor].*))
                return false;

            comptime b_ptr += @sizeOf(u32);

            if (comptime b_ptr == b.len) return true;
        }
    }

    if (comptime (len & 2) != 0) {
        if (@bitCast(u16, a[b_ptr..][0 .. @sizeOf(u16) / divisor].*) != comptime @bitCast(u16, slice[b_ptr .. b_ptr + (@sizeOf(u16) / divisor)].*))
            return false;

        comptime b_ptr += @sizeOf(u16);

        if (comptime b_ptr == b.len) return true;
    }

    if ((comptime (len & 1) != 0) and a[b_ptr] != comptime b[b_ptr]) return false;

    return true;
}

pub fn eqlCaseInsensitiveASCII(a: string, comptime b: anytype, comptime check_len: bool) bool {
    if (comptime check_len) {
        if (comptime b.len == 0) {
            return a.len == 0;
        }

        switch (a.len) {
            b.len => void{},
            else => return false,
        }
    }

    // pray to the auto vectorization gods
    inline for (b) |c, i| {
        const char = comptime std.ascii.toLower(c);
        if (char != std.ascii.toLower(a[i])) return false;
    }

    return true;
}

pub fn eqlLong(a_: string, b: string, comptime check_len: bool) bool {
    if (comptime check_len) {
        if (a_.len == 0) {
            return b.len == 0;
        }

        if (a_.len != b.len) {
            return false;
        }
    }

    const len = b.len;
    var dword_length = b.len >> 3;
    var b_ptr: usize = 0;
    const a = a_.ptr;

    while (dword_length > 0) : (dword_length -= 1) {
        const slice = b.ptr;
        if (@bitCast(usize, a[b_ptr..len][0..@sizeOf(usize)].*) != @bitCast(usize, (slice[b_ptr..b.len])[0..@sizeOf(usize)].*))
            return false;
        b_ptr += @sizeOf(usize);
        if (b_ptr == b.len) return true;
    }

    if (comptime @sizeOf(usize) == 8) {
        if ((len & 4) != 0) {
            const slice = b.ptr;
            if (@bitCast(u32, a[b_ptr..len][0..@sizeOf(u32)].*) != @bitCast(u32, (slice[b_ptr..b.len])[0..@sizeOf(u32)].*))
                return false;

            b_ptr += @sizeOf(u32);

            if (b_ptr == b.len) return true;
        }
    }

    if ((len & 2) != 0) {
        if (@bitCast(u16, a[b_ptr..len][0..@sizeOf(u16)].*) != @bitCast(u16, b.ptr[b_ptr..len][0..@sizeOf(u16)].*))
            return false;

        b_ptr += @sizeOf(u16);

        if (b_ptr == b.len) return true;
    }

    if (((len & 1) != 0) and a[b_ptr] != b[b_ptr]) return false;

    return true;
}

pub inline fn append(allocator: std.mem.Allocator, self: string, other: string) !string {
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ self, other });
}

pub inline fn joinBuf(out: []u8, parts: anytype, comptime parts_len: usize) []u8 {
    var remain = out;
    var count: usize = 0;
    comptime var i: usize = 0;
    inline while (i < parts_len) : (i += 1) {
        const part = parts[i];
        std.mem.copy(u8, remain, part);
        remain = remain[part.len..];
        count += part.len;
    }

    return out[0..count];
}

pub fn index(self: string, str: string) i32 {
    if (std.mem.indexOf(u8, self, str)) |i| {
        return @intCast(i32, i);
    } else {
        return -1;
    }
}

pub fn eqlUtf16(comptime self: string, other: []const u16) bool {
    return std.mem.eql(u16, std.unicode.utf8ToUtf16LeStringLiteral(self), other);
}

pub fn toUTF8Alloc(allocator: std.mem.Allocator, js: []const u16) !string {
    return try toUTF8AllocWithType(allocator, []const u16, js);
}

pub inline fn appendUTF8MachineWordToUTF16MachineWord(output: *[@sizeOf(usize) / 2]u16, input: *const [@sizeOf(usize) / 2]u8) void {
    comptime var i: usize = 0;
    inline while (i < @sizeOf(usize) / 2) : (i += 1) {
        output[i] = input[i];
    }
}

pub inline fn copyU8IntoU16(output_: []u16, input_: []const u8) void {
    var output = output_;
    var input = input_;
    const word = @sizeOf(usize) / 2;
    if (comptime Environment.allow_assert) {
        std.debug.assert(input.len <= output.len);
    }
    while (input.len >= word) {
        appendUTF8MachineWordToUTF16MachineWord(output[0..word], input[0..word]);
        output = output[word..];
        input = input[word..];
    }

    for (input) |c, i| {
        output[i] = c;
    }
}

pub inline fn appendUTF8MachineWordToUTF16MachineWordUnaligned(comptime alignment: u21, output: *align(alignment) [@sizeOf(usize) / 2]u16, input: *const [@sizeOf(usize) / 2]u8) void {
    comptime var i: usize = 0;
    inline while (i < @sizeOf(usize) / 2) : (i += 1) {
        output[i] = input[i];
    }
}

pub fn copyU8IntoU16WithAlignment(comptime alignment: u21, output_: []align(alignment) u16, input_: []const u8) void {
    var output = output_;
    var input = input_;
    const word = @sizeOf(usize) / 2;
    if (comptime Environment.allow_assert) {
        std.debug.assert(input.len <= output.len);
    }
    while (input.len >= word) {
        appendUTF8MachineWordToUTF16MachineWordUnaligned(alignment, output[0..word], input[0..word]);
        output = output[word..];
        input = input[word..];
    }

    for (input) |c, i| {
        output[i] = c;
    }
}

// pub inline fn copy(output_: []u8, input_: []const u8) void {
//     var output = output_;
//     var input = input_;
//     if (comptime Environment.allow_assert) {
//         std.debug.assert(input.len <= output.len);
//     }

//     if (input.len > @sizeOf(usize) * 4) {
//         comptime var i: usize = 0;
//         inline while (i < 4) : (i += 1) {
//             appendUTF8MachineWord(output[i * @sizeOf(usize) ..][0..@sizeOf(usize)], input[i * @sizeOf(usize) ..][0..@sizeOf(usize)]);
//         }
//         output = output[4 * @sizeOf(usize) ..];
//         input = input[4 * @sizeOf(usize) ..];
//     }

//     while (input.len >= @sizeOf(usize)) {
//         appendUTF8MachineWord(output[0..@sizeOf(usize)], input[0..@sizeOf(usize)]);
//         output = output[@sizeOf(usize)..];
//         input = input[@sizeOf(usize)..];
//     }

//     for (input) |c, i| {
//         output[i] = c;
//     }
// }

pub inline fn copyU16IntoU8(output_: []u8, comptime InputType: type, input_: InputType) void {
    var output = output_;
    var input = input_;
    if (comptime Environment.allow_assert) {
        std.debug.assert(input.len <= output.len);
    }

    // on X64, this is 4
    // on WASM, this is 2
    const machine_word_length = comptime @sizeOf(usize) / @sizeOf(u16);

    while (input.len >= machine_word_length) {
        comptime var machine_word_i: usize = 0;
        inline while (machine_word_i < machine_word_length) : (machine_word_i += 1) {
            output[machine_word_i] = @intCast(u8, input[machine_word_i]);
        }

        output = output[machine_word_length..];
        input = input[machine_word_length..];
    }

    for (input) |c, i| {
        output[i] = @intCast(u8, c);
    }
}

const strings = @This();

pub fn toUTF16Alloc(allocator: std.mem.Allocator, bytes: []const u8, comptime fail_if_invalid: bool) !?[]u16 {
    if (strings.firstNonASCII(bytes)) |i| {
        const ascii = bytes[0..i];
        const chunk = bytes[i..];
        var output = try std.ArrayList(u16).initCapacity(allocator, ascii.len + 2);
        errdefer output.deinit();
        output.items.len = ascii.len;
        strings.copyU8IntoU16(output.items, ascii);

        var remaining = chunk;

        {
            var sequence: [4]u8 = undefined;

            if (remaining.len >= 4) {
                sequence = remaining[0..4].*;
            } else {
                sequence[0] = remaining[0];
                sequence[1] = if (remaining.len > 1) remaining[1] else 0;
                sequence[2] = if (remaining.len > 2) remaining[2] else 0;
                sequence[3] = 0;
            }

            const replacement = strings.convertUTF8BytesIntoUTF16(&sequence);
            remaining = remaining[@maximum(replacement.len, 1)..];
            const new_len = strings.u16Len(replacement.code_point);
            try output.ensureUnusedCapacity(new_len);
            output.items.len += @as(usize, new_len);

            if (comptime fail_if_invalid) {
                if (replacement.code_point == unicode_replacement)
                    return error.InvalidByteSequence;
            }

            switch (replacement.code_point) {
                0...0xffff => {
                    output.items[output.items.len - 1] = @intCast(u16, replacement.code_point);
                },
                else => |c| {
                    output.items[output.items.len - 2 .. output.items.len][0..2].* = [2]u16{ strings.u16Lead(c), strings.u16Trail(c) };
                },
            }
        }

        while (strings.firstNonASCII(remaining)) |j| {
            const last = remaining[0..j];
            remaining = remaining[j..];

            var sequence: [4]u8 = undefined;

            if (remaining.len >= 4) {
                sequence = remaining[0..4].*;
            } else {
                sequence[0] = remaining[0];
                sequence[1] = if (remaining.len > 1) remaining[1] else 0;
                sequence[2] = if (remaining.len > 2) remaining[2] else 0;
                sequence[3] = 0;
            }

            const replacement = strings.convertUTF8BytesIntoUTF16(&sequence);
            remaining = remaining[@maximum(replacement.len, 1)..];
            const new_len = j + @as(usize, strings.u16Len(replacement.code_point));
            try output.ensureUnusedCapacity(new_len);
            output.items.len += new_len;
            strings.copyU8IntoU16(output.items[output.items.len - new_len ..][0..j], last);

            if (comptime fail_if_invalid) {
                if (replacement.code_point == unicode_replacement)
                    return error.InvalidByteSequence;
            }

            switch (replacement.code_point) {
                0...0xffff => {
                    output.items[output.items.len - 1] = @intCast(u16, replacement.code_point);
                },
                else => |c| {
                    output.items[output.items.len - 2 .. output.items.len][0..2].* = [2]u16{ strings.u16Lead(c), strings.u16Trail(c) };
                },
            }
        }

        if (remaining.len > 0) {
            try output.ensureUnusedCapacity(remaining.len);
            output.items.len += remaining.len;
            strings.copyU8IntoU16(output.items[output.items.len - remaining.len ..], remaining);
        }

        return output.items;
    }

    return null;
}

pub fn utf16Codepoint(comptime Type: type, input: Type) UTF16Replacement {
    const c0 = @as(u21, input[0]);

    if (c0 & ~@as(u21, 0x03ff) == 0xd800) {
        // surrogate pair
        if (input.len == 1)
            return .{
                .len = 1,
            };
        //error.DanglingSurrogateHalf;
        const c1 = @as(u21, input[1]);
        if (c1 & ~@as(u21, 0x03ff) != 0xdc00)
            if (input.len == 1)
                return .{
                    .len = 1,
                };
        // return error.ExpectedSecondSurrogateHalf;

        return .{ .len = 2, .code_point = 0x10000 + (((c0 & 0x03ff) << 10) | (c1 & 0x03ff)) };
    } else if (c0 & ~@as(u21, 0x03ff) == 0xdc00) {
        // return error.UnexpectedSecondSurrogateHalf;
        return .{ .len = 1 };
    } else {
        return .{ .code_point = c0, .len = 1 };
    }
}

pub fn toUTF8AllocWithType(allocator: std.mem.Allocator, comptime Type: type, utf16: Type) ![]u8 {
    var list = std.ArrayList(u8).initCapacity(allocator, utf16.len) catch unreachable;
    var utf16_remaining = utf16;

    while (firstNonASCII16(Type, utf16_remaining)) |i| {
        const to_copy = utf16_remaining[0..i];
        utf16_remaining = utf16_remaining[i..];

        const replacement = utf16Codepoint(Type, utf16_remaining);
        utf16_remaining = utf16_remaining[replacement.len..];

        const count: usize = switch (replacement.code_point) {
            0...0x7F => 1,
            (0x7F + 1)...0x7FF => 2,
            (0x7FF + 1)...0xFFFF => 3,
            else => 4,
        };
        try list.ensureUnusedCapacity(i + count);
        list.items.len += i;

        copyU16IntoU8(
            list.items[list.items.len - i ..],
            Type,
            to_copy,
        );

        list.items.len += count;

        _ = encodeWTF8RuneT(
            list.items.ptr[list.items.len - count .. list.items.len - count + 4][0..4],
            u32,
            @as(u32, replacement.code_point),
        );
    }

    try list.ensureUnusedCapacity(utf16_remaining.len);
    const old_len = list.items.len;
    list.items.len += utf16_remaining.len;
    copyU16IntoU8(list.items[old_len..], Type, utf16_remaining);

    return list.toOwnedSlice();
}

pub const EncodeIntoResult = struct {
    read: u32 = 0,
    written: u32 = 0,
};
pub fn allocateLatin1IntoUTF8(allocator: std.mem.Allocator, comptime Type: type, latin1_: Type) ![]u8 {
    var list = try std.ArrayList(u8).initCapacity(allocator, latin1_.len);
    var latin1 = latin1_;
    while (latin1.len > 0) {
        var read: usize = 0;
        var break_outer = false;

        outer: while (latin1.len >= 128) {
            try list.ensureUnusedCapacity(128);
            var base = list.items.ptr[list.items.len..list.items.len].ptr;

            comptime var count: usize = 0;
            inline while (count < 8) : (count += 1) {
                const vec: AsciiVector = latin1[(comptime count * ascii_vector_size)..][0..ascii_vector_size].*;
                const cmp = vec > max_16_ascii;
                const bitmask = @ptrCast(*const u16, &cmp).*;
                const first = @ctz(u16, bitmask);
                if (first < 16) {
                    latin1 = latin1[(comptime count * ascii_vector_size)..];
                    list.items.len += (comptime count * ascii_vector_size);
                    try list.appendSlice(latin1[0..first]);
                    latin1 = latin1[first..];
                    break_outer = true;
                    break :outer;
                }
                base[(comptime count * ascii_vector_size)..(comptime count * ascii_vector_size + ascii_vector_size)][0..ascii_vector_size].* = @bitCast([ascii_vector_size]u8, vec);
            }

            latin1 = latin1[(comptime count * ascii_vector_size)..];
            list.items.len += (comptime count * ascii_vector_size);
        }

        if (!break_outer) {
            while (latin1.len >= ascii_vector_size) {
                const vec: AsciiVector = latin1[0..ascii_vector_size].*;
                const cmp = vec > max_16_ascii;
                const bitmask = @ptrCast(*const u16, &cmp).*;
                const first = @ctz(u16, bitmask);
                if (first < 16) {
                    try list.appendSlice(latin1[0..first]);
                    latin1 = latin1[first..];
                    break;
                }

                try list.ensureUnusedCapacity(ascii_vector_size);
                list.items.len += ascii_vector_size;
                list.items[list.items.len - ascii_vector_size ..][0..ascii_vector_size].* = @bitCast([ascii_vector_size]u8, vec);
                latin1 = latin1[ascii_vector_size..];
            }
        }

        while (read < latin1.len and latin1[read] < 0x80) : (read += 1) {}
        try list.appendSlice(latin1[0..read]);
        latin1 = latin1[read..];

        if (latin1.len > 0) {
            try list.ensureUnusedCapacity(2);
            var buf = list.items.ptr[list.items.len .. list.items.len + 2][0..2];
            list.items.len += 2;
            buf[0..2].* = latin1ToCodepointBytesAssumeNotASCII(latin1[0]);
            latin1 = latin1[1..];
        }
    }

    return list.toOwnedSlice();
}

pub const UTF16Replacement = struct {
    code_point: u32 = unicode_replacement,
    len: u3 = 0,
};

// This variation matches WebKit behavior.
pub fn convertUTF8BytesIntoUTF16(sequence: *const [4]u8) UTF16Replacement {
    if (Environment.allow_assert)
        assert(sequence[0] > 127);
    const len = wtf8ByteSequenceLengthWithInvalid(sequence[0]);
    switch (len) {
        2 => {
            if (Environment.allow_assert)
                assert(sequence[0] >= 0xC2);
            if (Environment.allow_assert)
                assert(sequence[0] <= 0xDF);
            if (sequence[1] < 0x80 or sequence[1] > 0xBF) {
                return .{ .len = 1 };
            }
            return .{ .len = len, .code_point = ((@as(u32, sequence[0]) << 6) + @as(u32, sequence[1])) - 0x00003080 };
        },
        3 => {
            if (Environment.allow_assert)
                assert(sequence[0] >= 0xE0);
            if (Environment.allow_assert)
                assert(sequence[0] <= 0xEF);
            switch (sequence[0]) {
                0xE0 => {
                    if (sequence[1] < 0xA0 or sequence[1] > 0xBF) {
                        return .{ .len = 1 };
                    }
                },
                0xED => {
                    if (sequence[1] < 0x80 or sequence[1] > 0x9F) {
                        return .{ .len = 1 };
                    }
                },
                else => {
                    if (sequence[1] < 0x80 or sequence[1] > 0xBF) {
                        return .{ .len = 1 };
                    }
                },
            }
            if (sequence[2] < 0x80 or sequence[2] > 0xBF) {
                return .{ .len = 2 };
            }
            return .{
                .len = len,
                .code_point = ((@as(u32, sequence[0]) << 12) + (@as(u32, sequence[1]) << 6) + @as(u32, sequence[2])) - 0x000E2080,
            };
        },
        4 => {
            if (Environment.allow_assert)
                assert(sequence[0] >= 0xF0);
            if (Environment.allow_assert)
                assert(sequence[0] <= 0xF4);
            switch (sequence[0]) {
                0xF0 => {
                    if (sequence[1] < 0x90 or sequence[1] > 0xBF) {
                        return .{ .len = 1 };
                    }
                },
                0xF4 => {
                    if (sequence[1] < 0x80 or sequence[1] > 0x8F) {
                        return .{ .len = 1 };
                    }
                },
                else => {
                    if (sequence[1] < 0x80 or sequence[1] > 0xBF) {
                        return .{ .len = 1 };
                    }
                },
            }

            if (sequence[2] < 0x80 or sequence[2] > 0xBF) {
                return .{ .len = 2 };
            }
            if (sequence[3] < 0x80 or sequence[3] > 0xBF) {
                return .{ .len = 3 };
            }
            return .{
                .len = 4,
                .code_point = ((@as(u32, sequence[0]) << 18) +
                    (@as(u32, sequence[1]) << 12) +
                    (@as(u32, sequence[2]) << 6) + @as(u32, sequence[3])) - 0x03C82080,
            };
        },
        // invalid unicode sequence
        0 => return UTF16Replacement{ .len = 1 },
        else => unreachable,
    }
}

pub fn copyLatin1IntoUTF8(buf_: []u8, comptime Type: type, latin1_: Type) EncodeIntoResult {
    var buf = buf_;
    var latin1 = latin1_;
    while (buf.len > 0 and latin1.len > 0) {
        var read: usize = 0;

        while (latin1.len > ascii_vector_size) {
            const vec: AsciiVector = latin1[0..ascii_vector_size].*;
            const cmp = vec > max_16_ascii;
            const bitmask = @ptrCast(*const u16, &cmp).*;
            const first = @ctz(u16, bitmask);
            if (first < 16) {
                break;
            }
            buf[0..8].* = @bitCast([ascii_vector_size]u8, vec)[0..8].*;
            buf[8..ascii_vector_size].* = @bitCast([ascii_vector_size]u8, vec)[8..ascii_vector_size].*;
            latin1 = latin1[ascii_vector_size..];
            buf = buf[ascii_vector_size..];
        }

        while (read < latin1.len and latin1[read] < 0x80) : (read += 1) {}

        const written = @minimum(read, buf.len);
        if (written == 0) break;
        @memcpy(buf.ptr, latin1.ptr, written);
        latin1 = latin1[written..];
        buf = buf[written..];
        if (latin1.len > 0 and buf.len >= 2) {
            buf[0..2].* = latin1ToCodepointBytesAssumeNotASCII(latin1[0]);
            latin1 = latin1[1..];
            buf = buf[2..];
        }
    }

    return .{
        .read = @truncate(u32, buf_.len - buf.len),
        .written = @truncate(u32, latin1_.len - latin1.len),
    };
}

test "copyLatin1IntoUTF8" {
    var input: string = "hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!hello world!";
    var output = std.mem.zeroes([500]u8);
    const result = copyLatin1IntoUTF8(&output, string, input);
    try std.testing.expectEqual(input.len, result.read);
    try std.testing.expectEqual(input.len, result.written);

    try std.testing.expectEqualSlices(u8, input, output[0..result.written]);
}

pub fn latin1ToCodepointAssumeNotASCII(char: u8, comptime CodePointType: type) CodePointType {
    return @intCast(
        CodePointType,
        @bitCast(
            u16,
            latin1ToCodepointBytesAssumeNotASCII(char),
        ),
    );
}

pub fn latin1ToCodepointBytesAssumeNotASCII(char: u32) [2]u8 {
    return [2]u8{
        @truncate(u8, 0xc0 | char >> 6),
        @truncate(u8, 0x80 | (char & 0x3f)),
    };
}

pub fn copyUTF16IntoUTF8(buf: []u8, comptime Type: type, utf16: Type) EncodeIntoResult {
    var remaining = buf;
    var utf16_remaining = utf16;
    var ended_on_non_ascii = false;

    while (firstNonASCII16(Type, utf16_remaining)) |i| {
        const end = @minimum(i, remaining.len);
        const to_copy = utf16_remaining[0..end];
        copyU16IntoU8(remaining, Type, to_copy);
        remaining = remaining[end..];
        utf16_remaining = utf16_remaining[end..];

        if (@minimum(utf16_remaining.len, remaining.len) == 0)
            break;

        const replacement = utf16Codepoint(Type, utf16_remaining);

        const width: usize = switch (replacement.code_point) {
            0...0x7F => 1,
            (0x7F + 1)...0x7FF => 2,
            (0x7FF + 1)...0xFFFF => 3,
            else => 4,
        };

        if (width > remaining.len) {
            ended_on_non_ascii = width > 1;
            break;
        }

        utf16_remaining = utf16_remaining[replacement.len..];
        _ = encodeWTF8RuneT(remaining.ptr[0..4], u32, @as(u32, replacement.code_point));
        remaining = remaining[width..];
    }

    if (remaining.len > 0 and !ended_on_non_ascii and utf16_remaining.len > 0) {
        const len = @minimum(remaining.len, utf16_remaining.len);
        copyU16IntoU8(remaining[0..len], Type, utf16_remaining[0..len]);
        utf16_remaining = utf16_remaining[len..];
        remaining = remaining[len..];
    }

    return .{
        .read = @truncate(u32, utf16.len - utf16_remaining.len),
        .written = @truncate(u32, buf.len - remaining.len),
    };
}

// Check utf16 string equals utf8 string without allocating extra memory
pub fn utf16EqlString(text: []const u16, str: string) bool {
    if (text.len > str.len) {
        // Strings can't be equal if UTF-16 encoding is longer than UTF-8 encoding
        return false;
    }

    var temp = [4]u8{ 0, 0, 0, 0 };
    const n = text.len;
    var j: usize = 0;
    var i: usize = 0;
    // TODO: is it safe to just make this u32 or u21?
    var r1: i32 = undefined;
    var k: u4 = 0;
    while (i < n) : (i += 1) {
        r1 = text[i];
        if (r1 >= 0xD800 and r1 <= 0xDBFF and i + 1 < n) {
            const r2: i32 = text[i + 1];
            if (r2 >= 0xDC00 and r2 <= 0xDFFF) {
                r1 = (r1 - 0xD800) << 10 | (r2 - 0xDC00) + 0x10000;
                i += 1;
            }
        }

        const width = encodeWTF8Rune(&temp, r1);
        if (j + width > str.len) {
            return false;
        }
        k = 0;
        while (k < width) : (k += 1) {
            if (temp[k] != str[j]) {
                return false;
            }
            j += 1;
        }
    }

    return j == str.len;
}

// This is a clone of golang's "utf8.EncodeRune" that has been modified to encode using
// WTF-8 instead. See https://simonsapin.github.io/wtf-8/ for more info.
pub fn encodeWTF8Rune(p: *[4]u8, r: i32) u3 {
    return @call(
        .{
            .modifier = .always_inline,
        },
        encodeWTF8RuneT,
        .{
            p,
            u32,
            @intCast(u32, r),
        },
    );
}

pub fn encodeWTF8RuneT(p: *[4]u8, comptime R: type, r: R) u3 {
    switch (r) {
        0...0x7F => {
            p[0] = @intCast(u8, r);
            return 1;
        },
        (0x7F + 1)...0x7FF => {
            p[0] = @truncate(u8, 0xC0 | ((r >> 6)));
            p[1] = @truncate(u8, 0x80 | (r & 0x3F));
            return 2;
        },
        (0x7FF + 1)...0xFFFF => {
            p[0] = @truncate(u8, 0xE0 | ((r >> 12)));
            p[1] = @truncate(u8, 0x80 | ((r >> 6) & 0x3F));
            p[2] = @truncate(u8, 0x80 | (r & 0x3F));
            return 3;
        },
        else => {
            p[0] = @truncate(u8, 0xF0 | ((r >> 18)));
            p[1] = @truncate(u8, 0x80 | ((r >> 12) & 0x3F));
            p[2] = @truncate(u8, 0x80 | ((r >> 6) & 0x3F));
            p[3] = @truncate(u8, 0x80 | (r & 0x3F));
            return 4;
        },
    }
}

pub inline fn wtf8ByteSequenceLength(first_byte: u8) u3 {
    return switch (first_byte) {
        0 => 0,
        1...0x80 - 1 => 1,
        else => if ((first_byte & 0xE0) == 0xC0)
            @as(u3, 2)
        else if ((first_byte & 0xF0) == 0xE0)
            @as(u3, 3)
        else if ((first_byte & 0xF8) == 0xF0)
            @as(u3, 4)
        else
            @as(u3, 1),
    };
}

/// 0 == invalid
pub inline fn wtf8ByteSequenceLengthWithInvalid(first_byte: u8) u3 {
    return switch (first_byte) {
        0...0x80 - 1 => 1,
        else => if ((first_byte & 0xE0) == 0xC0)
            @as(u3, 2)
        else if ((first_byte & 0xF0) == 0xE0)
            @as(u3, 3)
        else if ((first_byte & 0xF8) == 0xF0)
            @as(u3, 4)
        else
            @as(u3, 1),
    };
}

/// Convert potentially ill-formed UTF-8 or UTF-16 bytes to a Unicode Codepoint.
/// Invalid codepoints are replaced with `zero` parameter
/// This is a clone of esbuild's decodeWTF8Rune
/// which was a clone of golang's "utf8.DecodeRune" that was modified to decode using WTF-8 instead.
/// Asserts a multi-byte codepoint
pub inline fn decodeWTF8RuneTMultibyte(p: *const [4]u8, len: u3, comptime T: type, comptime zero: T) T {
    std.debug.assert(len > 1);

    const s1 = p[1];
    if ((s1 & 0xC0) != 0x80) return zero;

    if (len == 2) {
        const cp = @as(T, p[0] & 0x1F) << 6 | @as(T, s1 & 0x3F);
        if (cp < 0x80) return zero;
        return cp;
    }

    const s2 = p[2];

    if ((s2 & 0xC0) != 0x80) return zero;

    if (len == 3) {
        const cp = (@as(T, p[0] & 0x0F) << 12) | (@as(T, s1 & 0x3F) << 6) | (@as(T, s2 & 0x3F));
        if (cp < 0x800) return zero;
        return cp;
    }

    const s3 = p[3];
    {
        const cp = (@as(T, p[0] & 0x07) << 18) | (@as(T, s1 & 0x3F) << 12) | (@as(T, s2 & 0x3F) << 6) | (@as(T, s3 & 0x3F));
        if (cp < 0x10000 or cp > 0x10FFFF) return zero;
        return cp;
    }

    unreachable;
}

pub const ascii_vector_size = if (Environment.isWasm) 8 else 16;
pub const ascii_u16_vector_size = if (Environment.isWasm) 4 else 8;
pub const AsciiVectorInt = std.meta.Int(.unsigned, ascii_vector_size);
pub const AsciiVectorIntU16 = std.meta.Int(.unsigned, ascii_u16_vector_size);
pub const max_16_ascii = @splat(ascii_vector_size, @as(u8, 127));
pub const min_16_ascii = @splat(ascii_vector_size, @as(u8, 0x20));
pub const max_u16_ascii = @splat(ascii_u16_vector_size, @as(u16, 127));
pub const min_u16_ascii = @splat(ascii_u16_vector_size, @as(u16, 0x20));
pub const AsciiVector = std.meta.Vector(ascii_vector_size, u8);
pub const AsciiVectorU1 = std.meta.Vector(ascii_vector_size, u1);
pub const AsciiVectorU16U1 = std.meta.Vector(ascii_u16_vector_size, u1);
pub const AsciiU16Vector = std.meta.Vector(ascii_u16_vector_size, u16);
pub const max_4_ascii = @splat(4, @as(u8, 127));
pub fn isAllASCII(slice: []const u8) bool {
    var remaining = slice;

    // The NEON SIMD unit is 128-bit wide and includes 16 128-bit registers that can be used as 32 64-bit registers
    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= 128) {
            comptime var count: usize = 0;
            inline while (count < 8) : (count += 1) {
                const vec: AsciiVector = remaining[(comptime count * ascii_vector_size)..][0..ascii_vector_size].*;

                if ((@reduce(.Or, vec > max_16_ascii))) {
                    return false;
                }
            }
            remaining = remaining[comptime ascii_vector_size * count..];
        }

        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;

            if ((@reduce(.Or, vec > max_16_ascii))) {
                return false;
            }

            remaining = remaining[ascii_vector_size..];
        }

        while (remaining.len >= 4) {
            const vec: std.meta.Vector(4, u8) = remaining[0..4].*;

            remaining = remaining[4..];
            if (@reduce(.Or, vec > max_4_ascii)) {
                return false;
            }
        }
    }

    for (remaining) |char| {
        if (char > 127) {
            return false;
        }
    }

    return true;
}

//#define U16_LEAD(supplementary) (UChar)(((supplementary)>>10)+0xd7c0)
pub inline fn u16Lead(supplementary: anytype) u16 {
    return @intCast(u16, (supplementary >> 10) + 0xd7c0);
}

//#define U16_TRAIL(supplementary) (UChar)(((supplementary)&0x3ff)|0xdc00)
pub inline fn u16Trail(supplementary: anytype) u16 {
    return @intCast(u16, (supplementary & 0x3ff) | 0xdc00);
}

//#define U16_LENGTH(c) ((uint32_t)(c)<=0xffff ? 1 : 2)
pub inline fn u16Len(supplementary: anytype) u2 {
    return switch (@intCast(u32, supplementary)) {
        0...0xffff => 1,
        else => 2,
    };
}

pub fn firstNonASCII(slice: []const u8) ?u32 {
    var remaining = slice;

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;
            const cmp = vec > max_16_ascii;
            const bitmask = @ptrCast(*const AsciiVectorInt, &cmp).*;
            const first = @ctz(AsciiVectorInt, bitmask);
            if (first < ascii_vector_size) {
                return @as(u32, first) + @intCast(u32, slice.len - remaining.len);
            }

            remaining = remaining[ascii_vector_size..];
        }
    }

    for (remaining) |char, i| {
        if (char > 127) {
            return @truncate(u32, i + (slice.len - remaining.len));
        }
    }

    return null;
}

pub fn indexOfNewlineOrNonASCII(slice_: []const u8, offset: u32) ?u32 {
    return indexOfNewlineOrNonASCIICheckStart(slice_, offset, true);
}

pub fn indexOfNewlineOrNonASCIICheckStart(slice_: []const u8, offset: u32, comptime check_start: bool) ?u32 {
    const slice = slice_[offset..];
    var remaining = slice;

    if (remaining.len == 0)
        return null;

    if (comptime check_start) {
        // this shows up in profiling
        if (remaining[0] > 127 or remaining[0] < 0x20 or remaining[0] == '\r' or remaining[0] == '\n') {
            return offset;
        }
    }

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;
            const cmp = @bitCast(AsciiVectorU1, (vec > max_16_ascii)) | @bitCast(AsciiVectorU1, (vec < min_16_ascii)) |
                @bitCast(AsciiVectorU1, vec == @splat(ascii_vector_size, @as(u8, '\r'))) |
                @bitCast(AsciiVectorU1, vec == @splat(ascii_vector_size, @as(u8, '\n')));
            const bitmask = @ptrCast(*const AsciiVectorInt, &cmp).*;
            const first = @ctz(AsciiVectorInt, bitmask);
            if (first < ascii_vector_size) {
                return @as(u32, first) + @intCast(u32, slice.len - remaining.len) + offset;
            }

            remaining = remaining[ascii_vector_size..];
        }
    }

    for (remaining) |char, i| {
        if (char > 127 or char < 0x20 or char == '\n' or char == '\r') {
            return @truncate(u32, i + (slice.len - remaining.len)) + offset;
        }
    }

    return null;
}

pub fn indexOfNeedsEscape(slice: []const u8) ?u32 {
    var remaining = slice;
    if (remaining.len == 0)
        return null;

    if (remaining[0] > 127 or remaining[0] < 0x20 or remaining[0] == '\\' or remaining[0] == '"') {
        return 0;
    }

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;
            const cmp = @bitCast(AsciiVectorU1, (vec > max_16_ascii)) | @bitCast(AsciiVectorU1, (vec < min_16_ascii)) |
                @bitCast(AsciiVectorU1, vec == @splat(ascii_vector_size, @as(u8, '\\'))) |
                @bitCast(AsciiVectorU1, vec == @splat(ascii_vector_size, @as(u8, '"')));
            const bitmask = @ptrCast(*const AsciiVectorInt, &cmp).*;
            const first = @ctz(AsciiVectorInt, bitmask);
            if (first < ascii_vector_size) {
                return @as(u32, first) + @intCast(u32, slice.len - remaining.len);
            }

            remaining = remaining[ascii_vector_size..];
        }
    }

    for (remaining) |char, i| {
        if (char > 127 or char < 0x20 or char == '\\' or char == '"') {
            return @truncate(u32, i + (slice.len - remaining.len));
        }
    }

    return null;
}

test "indexOfNeedsEscape" {
    const out = indexOfNeedsEscape(
        \\la la la la la la la la la la la la la la la la "oh!" okay "well"
        ,
    );
    try std.testing.expectEqual(out.?, 48);
}

pub fn indexOfChar(slice: []const u8, char: u8) ?u32 {
    var remaining = slice;
    if (remaining.len == 0)
        return null;

    if (remaining[0] == char)
        return 0;

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;
            const cmp = vec == @splat(ascii_vector_size, char);
            const bitmask = @ptrCast(*const AsciiVectorInt, &cmp).*;
            const first = @ctz(AsciiVectorInt, bitmask);
            if (first < 16) {
                return @intCast(u32, @as(u32, first) + @intCast(u32, slice.len - remaining.len));
            }
            remaining = remaining[ascii_vector_size..];
        }
    }

    for (remaining) |c, i| {
        if (c == char) {
            return @truncate(u32, i + (slice.len - remaining.len));
        }
    }

    return null;
}

test "indexOfChar" {
    const pairs = .{
        .{
            "fooooooboooooofoooooofoooooofoooooofoooooozball",
            'b',
        },
        .{
            "foooooofoooooofoooooofoooooofoooooofoooooozball",
            'z',
        },
        .{
            "foooooofoooooofoooooofoooooofoooooofoooooozball",
            'a',
        },
        .{
            "foooooofoooooofoooooofoooooofoooooofoooooozball",
            'l',
        },
        .{
            "baconaopsdkaposdkpaosdkpaosdkaposdkpoasdkpoaskdpoaskdpoaskdpo;",
            ';',
        },
        .{
            ";baconaopsdkaposdkpaosdkpaosdkaposdkpoasdkpoaskdpoaskdpoaskdpo;",
            ';',
        },
    };
    inline for (pairs) |pair| {
        try std.testing.expectEqual(
            indexOfChar(pair.@"0", pair.@"1").?,
            @truncate(u32, std.mem.indexOfScalar(u8, pair.@"0", pair.@"1").?),
        );
    }
}

pub fn indexOfNotChar(slice: []const u8, char: u8) ?u32 {
    var remaining = slice;
    if (remaining.len == 0)
        return null;

    if (remaining[0] != char)
        return 0;

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_vector_size) {
            const vec: AsciiVector = remaining[0..ascii_vector_size].*;
            const cmp = vec != @splat(ascii_vector_size, char);
            const bitmask = @ptrCast(*const AsciiVectorInt, &cmp).*;
            const first = @ctz(AsciiVectorInt, bitmask);
            if (first < ascii_vector_size) {
                return @as(u32, first) + @intCast(u32, slice.len - remaining.len);
            }

            remaining = remaining[ascii_vector_size..];
        }
    }

    while (remaining.len > 0) {
        if (remaining[0] != char) {
            return @truncate(u32, (slice.len - remaining.len));
        }
        remaining = remaining[1..];
    }

    return null;
}

pub fn trimLeadingChar(slice: []const u8, char: u8) []const u8 {
    if (indexOfNotChar(slice, char)) |i| {
        return slice[i..];
    }

    return "";
}

pub fn containsAnyBesidesChar(bytes: []const u8, char: u8) bool {
    var remain = bytes;
    while (remain.len >= ascii_vector_size) {
        const vec: AsciiVector = remain[0..ascii_vector_size].*;
        const comparator = @splat(ascii_vector_size, char);
        remain = remain[ascii_vector_size..];
        if ((@reduce(.Or, vec != comparator))) {
            return true;
        }
    }

    while (remain.len > 0) {
        if (remain[0] != char) {
            return true;
        }
        remain = remain[1..];
    }

    return bytes.len > 0;
}

pub fn firstNonASCII16(comptime Slice: type, slice: Slice) ?u32 {
    return firstNonASCII16CheckMin(Slice, slice, true);
}

/// Get the line number and the byte offsets of `line_range_count` above the desired line number
/// The final element is the end index of the desired line
pub fn indexOfLineNumber(text: []const u8, line: u32, comptime line_range_count: usize) ?[line_range_count + 1]u32 {
    var ranges = std.mem.zeroes([line_range_count + 1]u32);
    var remaining = text;
    if (remaining.len == 0 or line == 0) return null;

    var iter = CodepointIterator.init(text);
    var cursor = CodepointIterator.Cursor{};
    var count: u32 = 0;

    while (iter.next(&cursor)) {
        switch (cursor.c) {
            '\n', '\r' => {
                if (cursor.c == '\r' and text[cursor.i..].len > 0 and text[cursor.i + 1] == '\n') {
                    cursor.i += 1;
                }

                if (comptime line_range_count > 1) {
                    comptime var i: usize = 0;
                    inline while (i < line_range_count) : (i += 1) {
                        std.mem.swap(u32, &ranges[i], &ranges[i + 1]);
                    }
                } else {
                    ranges[0] = ranges[1];
                }

                ranges[line_range_count] = cursor.i;

                if (count == line) {
                    return ranges;
                }

                count += 1;
            },
            else => {},
        }
    }

    return null;
}

/// Get N lines from the start of the text
pub fn getLinesInText(text: []const u8, line: u32, comptime line_range_count: usize) ?[line_range_count][]const u8 {
    const ranges = indexOfLineNumber(text, line, line_range_count) orelse return null;
    var results = std.mem.zeroes([line_range_count][]const u8);
    var i: usize = 0;
    var any_exist = false;
    while (i < line_range_count) : (i += 1) {
        results[i] = text[ranges[i]..ranges[i + 1]];
        any_exist = any_exist or results[i].len > 0;
    }

    if (!any_exist)
        return null;
    return results;
}

pub fn firstNonASCII16CheckMin(comptime Slice: type, slice: Slice, comptime check_min: bool) ?u32 {
    var remaining = slice;

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_u16_vector_size) {
            const vec: AsciiU16Vector = remaining[0..ascii_u16_vector_size].*;

            if (comptime check_min) {
                const cmp = @bitCast(AsciiVectorU16U1, vec > max_u16_ascii) |
                    @bitCast(AsciiVectorU16U1, vec < min_u16_ascii);

                const bitmask = @ptrCast(*const u16, &cmp).*;
                const first = @ctz(u16, bitmask);
                if (first < ascii_u16_vector_size) {
                    return @intCast(u32, @as(u32, first) +
                        @intCast(u32, slice.len - remaining.len));
                }
            }

            if (comptime !check_min) {
                const cmp = vec > max_u16_ascii;
                const bitmask = @ptrCast(*const u16, &cmp).*;
                const first = @ctz(u16, bitmask);

                if (first < ascii_u16_vector_size) {
                    return @intCast(u32, @as(u32, first) +
                        @intCast(u32, slice.len - remaining.len));
                }
            }

            remaining = remaining[ascii_u16_vector_size..];
        }
    }

    if (comptime check_min) {
        for (remaining) |char, i| {
            if (char > 127 or char < 0x20) {
                return @truncate(u32, i + (slice.len - remaining.len));
            }
        }
    } else {
        for (remaining) |char, i| {
            if (char > 127) {
                return @truncate(u32, i + (slice.len - remaining.len));
            }
        }
    }

    return null;
}

/// Fast path for printing template literal strings 
pub fn @"nextUTF16NonASCIIOr$`\\"(
    comptime Slice: type,
    slice: Slice,
) ?u32 {
    var remaining = slice;

    if (comptime Environment.isAarch64 or Environment.isX64) {
        while (remaining.len >= ascii_u16_vector_size) {
            const vec: AsciiU16Vector = remaining[0..ascii_u16_vector_size].*;

            const cmp = @bitCast(AsciiVectorU16U1, (vec > max_u16_ascii)) |
                @bitCast(AsciiVectorU16U1, (vec < min_u16_ascii)) |
                @bitCast(AsciiVectorU16U1, (vec == @splat(ascii_u16_vector_size, @as(u16, '$')))) |
                @bitCast(AsciiVectorU16U1, (vec == @splat(ascii_u16_vector_size, @as(u16, '`')))) |
                @bitCast(AsciiVectorU16U1, (vec == @splat(ascii_u16_vector_size, @as(u16, '\\'))));

            const bitmask = @ptrCast(*const u8, &cmp).*;
            const first = @ctz(u8, bitmask);
            if (first < ascii_u16_vector_size) {
                return @intCast(u32, @as(u32, first) +
                    @intCast(u32, slice.len - remaining.len));
            }

            remaining = remaining[ascii_u16_vector_size..];
        }
    }

    for (remaining) |char, i| {
        switch (char) {
            '$', '`', '\\', 0...0x20 - 1, 128...std.math.maxInt(u16) => {
                return @truncate(u32, i + (slice.len - remaining.len));
            },

            else => {},
        }
    }

    return null;
}

test "indexOfNotChar" {
    {
        const yes = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        try std.testing.expectEqual(indexOfNotChar(yes, 'a').?, 36);
    }
    {
        const yes = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        try std.testing.expectEqual(indexOfNotChar(yes, 'a').?, 108);
    }
}

test "trimLeadingChar" {
    {
        const yes = "                                                                        fooo bar";
        try std.testing.expectEqualStrings(trimLeadingChar(yes, ' '), "fooo bar");
    }
}

test "isAllASCII" {
    const yes = "aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123";
    try std.testing.expectEqual(true, isAllASCII(yes));

    const no = "aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdoka🙂sdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123";
    try std.testing.expectEqual(false, isAllASCII(no));
}

test "firstNonASCII" {
    const yes = "aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123";
    try std.testing.expectEqual(true, firstNonASCII(yes) == null);

    {
        const no = "aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdoka🙂sdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123";
        try std.testing.expectEqual(@as(u32, 50), firstNonASCII(no).?);
    }

    {
        const no = "aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd12312🙂3";
        try std.testing.expectEqual(@as(u32, 366), firstNonASCII(no).?);
    }
}

test "firstNonASCII16" {
    @setEvalBranchQuota(99999);
    const yes = std.mem.span(std.unicode.utf8ToUtf16LeStringLiteral("aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123"));
    try std.testing.expectEqual(true, firstNonASCII16(@TypeOf(yes), yes) == null);

    {
        @setEvalBranchQuota(99999);
        const no = std.mem.span(std.unicode.utf8ToUtf16LeStringLiteral("aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdoka🙂sdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123"));
        try std.testing.expectEqual(@as(u32, 50), firstNonASCII16(@TypeOf(no), no).?);
    }
    {
        @setEvalBranchQuota(99999);
        const no = std.mem.span(std.unicode.utf8ToUtf16LeStringLiteral("🙂sdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123"));
        try std.testing.expectEqual(@as(u32, 0), firstNonASCII16(@TypeOf(no), no).?);
    }
    {
        @setEvalBranchQuota(99999);
        const no = std.mem.span(std.unicode.utf8ToUtf16LeStringLiteral("a🙂sdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123"));
        try std.testing.expectEqual(@as(u32, 1), firstNonASCII16(@TypeOf(no), no).?);
    }
    {
        @setEvalBranchQuota(99999);
        const no = std.mem.span(std.unicode.utf8ToUtf16LeStringLiteral("aspdokasdpokasdpokasd aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd123123aspdokasdpokasdpokasdaspdokasdpokasdpokasdaspdokasdpokasdpokasd12312🙂3"));
        try std.testing.expectEqual(@as(u32, 366), firstNonASCII16(@TypeOf(no), no).?);
    }
}

pub fn formatUTF16(slice_: []align(1) const u16, writer: anytype) !void {
    var slice = slice_;
    var chunk: [512 + 4]u8 = undefined;
    var chunk_i: u16 = 0;

    while (slice.len > 0) {
        if (chunk_i >= chunk.len - 5) {
            try writer.writeAll(chunk[0..chunk_i]);
            chunk_i = 0;
        }

        var cp: u32 = slice[0];
        slice = slice[1..];
        if (cp & ~@as(u32, 0x03ff) == 0xd800 and slice.len > 0) {
            cp = 0x10000 + (((cp & 0x03ff) << 10) | (slice[0] & 0x03ff));
            slice = slice[1..];
        }

        chunk_i += @as(
            u8,
            @call(
                .{ .modifier = .always_inline },
                encodeWTF8RuneT,
                .{ chunk[chunk_i..][0..4], u32, cp },
            ),
        );
    }

    try writer.writeAll(chunk[0..chunk_i]);
}

test "print UTF16" {
    var err = std.io.getStdErr();
    const utf16 = comptime std.unicode.utf8ToUtf16LeStringLiteral("❌ ✅ opkay ");
    try formatUTF16(utf16, err.writer());
    // std.unicode.fmtUtf16le(utf16le: []const u16)
}

/// Convert potentially ill-formed UTF-8 or UTF-16 bytes to a Unicode Codepoint.
/// - Invalid codepoints are replaced with `zero` parameter
/// - Null bytes return 0
pub fn decodeWTF8RuneT(p: *const [4]u8, len: u3, comptime T: type, comptime zero: T) T {
    if (len == 0) return zero;
    if (len == 1) return p[0];

    return decodeWTF8RuneTMultibyte(p, len, T, zero);
}

pub fn codepointSize(comptime R: type, r: R) u3 {
    return switch (r) {
        0b0000_0000...0b0111_1111 => 1,
        0b1100_0000...0b1101_1111 => 2,
        0b1110_0000...0b1110_1111 => 3,
        0b1111_0000...0b1111_0111 => 4,
        else => 0,
    };
}

// /// Encode Type into UTF-8 bytes.
// /// - Invalid unicode data becomes U+FFFD REPLACEMENT CHARACTER.
// /// -
// pub fn encodeUTF8RuneT(out: *[4]u8, comptime R: type, c: R) u3 {
//     switch (c) {
//         0b0000_0000...0b0111_1111 => {
//             out[0] = @intCast(u8, c);
//             return 1;
//         },
//         0b1100_0000...0b1101_1111 => {
//             out[0] = @truncate(u8, 0b11000000 | (c >> 6));
//             out[1] = @truncate(u8, 0b10000000 | c & 0b111111);
//             return 2;
//         },

//         0b1110_0000...0b1110_1111 => {
//             if (0xd800 <= c and c <= 0xdfff) {
//                 // Replacement character
//                 out[0..3].* = [_]u8{ 0xEF, 0xBF, 0xBD };

//                 return 3;
//             }

//             out[0] = @truncate(u8, 0b11100000 | (c >> 12));
//             out[1] = @truncate(u8, 0b10000000 | (c >> 6) & 0b111111);
//             out[2] = @truncate(u8, 0b10000000 | c & 0b111111);
//             return 3;
//         },
//         0b1111_0000...0b1111_0111 => {
//             out[0] = @truncate(u8, 0b11110000 | (c >> 18));
//             out[1] = @truncate(u8, 0b10000000 | (c >> 12) & 0b111111);
//             out[2] = @truncate(u8, 0b10000000 | (c >> 6) & 0b111111);
//             out[3] = @truncate(u8, 0b10000000 | c & 0b111111);
//             return 4;
//         },
//         else => {
//             // Replacement character
//             out[0..3].* = [_]u8{ 0xEF, 0xBF, 0xBD };

//             return 3;
//         },
//     }
// }

pub fn containsNonBmpCodePoint(text: string) bool {
    var iter = CodepointIterator.init(text);
    var curs = CodepointIterator.Cursor{};

    while (iter.next(&curs)) {
        if (curs.c > 0xFFFF) {
            return true;
        }
    }

    return false;
}

// this is std.mem.trim except it doesn't forcibly change the slice to be const
pub fn trim(slice: anytype, values_to_strip: []const u8) @TypeOf(slice) {
    var begin: usize = 0;
    var end: usize = slice.len;
    while (begin < end and std.mem.indexOfScalar(u8, values_to_strip, slice[begin]) != null) : (begin += 1) {}
    while (end > begin and std.mem.indexOfScalar(u8, values_to_strip, slice[end - 1]) != null) : (end -= 1) {}
    return slice[begin..end];
}

pub fn containsNonBmpCodePointUTF16(_text: []const u16) bool {
    const n = _text.len;
    if (n > 0) {
        var i: usize = 0;
        var text = _text[0 .. n - 1];
        while (i < n - 1) : (i += 1) {
            switch (text[i]) {
                // Check for a high surrogate
                0xD800...0xDBFF => {
                    // Check for a low surrogate
                    switch (text[i + 1]) {
                        0xDC00...0xDFFF => {
                            return true;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }

    return false;
}

pub fn join(slices: []const string, delimiter: string, allocator: std.mem.Allocator) !string {
    return try std.mem.join(allocator, delimiter, slices);
}

pub fn cmpStringsAsc(_: void, a: string, b: string) bool {
    return std.mem.order(u8, a, b) == .lt;
}

pub fn cmpStringsDesc(_: void, a: string, b: string) bool {
    return std.mem.order(u8, a, b) == .gt;
}

const sort_asc = std.sort.asc(u8);
const sort_desc = std.sort.desc(u8);

pub fn sortAsc(in: []string) void {
    // TODO: experiment with simd to see if it's faster
    std.sort.sort([]const u8, in, {}, cmpStringsAsc);
}

pub fn sortDesc(in: []string) void {
    // TODO: experiment with simd to see if it's faster
    std.sort.sort([]const u8, in, {}, cmpStringsDesc);
}

pub fn isASCIIHexDigit(c: u8) bool {
    return std.ascii.isDigit(c) or std.ascii.isXDigit(c);
}

pub fn toASCIIHexValue(character: u8) u8 {
    std.debug.assert(isASCIIHexDigit(character));
    return switch (character) {
        0...('A' - 1) => character - '0',
        else => (character - 'A' + 10) & 0xF,
    };
}

pub inline fn utf8ByteSequenceLength(first_byte: u8) u3 {
    return switch (first_byte) {
        0b0000_0000...0b0111_1111 => 1,
        0b1100_0000...0b1101_1111 => 2,
        0b1110_0000...0b1110_1111 => 3,
        0b1111_0000...0b1111_0111 => 4,
        else => 0,
    };
}

pub fn NewCodePointIterator(comptime CodePointType: type, comptime zeroValue: comptime_int) type {
    return struct {
        const Iterator = @This();
        bytes: []const u8,
        i: usize,
        next_width: usize = 0,
        width: u3 = 0,
        c: CodePointType = zeroValue,

        pub const Cursor = struct {
            i: u32 = 0,
            c: CodePointType = zeroValue,
            width: u3 = 0,
        };

        pub fn init(str: string) Iterator {
            return Iterator{ .bytes = str, .i = 0, .c = zeroValue };
        }

        pub fn initOffset(str: string, i: usize) Iterator {
            return Iterator{ .bytes = str, .i = i, .c = zeroValue };
        }

        pub inline fn next(it: *const Iterator, cursor: *Cursor) bool {
            const pos: u32 = @as(u32, cursor.width) + cursor.i;
            if (pos >= it.bytes.len) {
                return false;
            }

            const cp_len = wtf8ByteSequenceLength(it.bytes[pos]);
            const error_char = comptime std.math.minInt(CodePointType);

            const codepoint = @as(
                CodePointType,
                switch (cp_len) {
                    0 => return false,
                    1 => it.bytes[pos],
                    else => decodeWTF8RuneTMultibyte(it.bytes[pos..].ptr[0..4], cp_len, CodePointType, error_char),
                },
            );

            cursor.* = Cursor{
                .i = pos,
                .c = if (error_char != codepoint)
                    codepoint
                else
                    unicode_replacement,
                .width = if (codepoint != error_char) cp_len else 1,
            };

            return true;
        }

        inline fn nextCodepointSlice(it: *Iterator) []const u8 {
            const bytes = it.bytes;
            const prev = it.i;
            const next_ = prev + it.next_width;
            if (bytes.len <= next_) return "";

            const cp_len = utf8ByteSequenceLength(bytes[next_]);
            it.next_width = cp_len;
            it.i = @minimum(next_, bytes.len);

            const slice = bytes[prev..][0..cp_len];
            it.width = @intCast(u3, slice.len);
            return slice;
        }

        pub fn needsUTF8Decoding(slice: string) bool {
            var it = Iterator{ .bytes = slice, .i = 0 };

            while (true) {
                const part = it.nextCodepointSlice();
                @setRuntimeSafety(false);
                switch (part.len) {
                    0 => return false,
                    1 => continue,
                    else => return true,
                }
            }
        }

        pub fn scanUntilQuotedValueOrEOF(iter: *Iterator, comptime quote: CodePointType) usize {
            while (iter.c > -1) {
                if (!switch (iter.nextCodepoint()) {
                    quote => false,
                    '\\' => brk: {
                        if (iter.nextCodepoint() == quote) {
                            continue;
                        }
                        break :brk true;
                    },
                    else => true,
                }) {
                    return iter.i + 1;
                }
            }

            return iter.i;
        }

        pub fn nextCodepoint(it: *Iterator) CodePointType {
            const slice = it.nextCodepointSlice();

            it.c = switch (slice.len) {
                0 => zeroValue,
                1 => @intCast(CodePointType, slice[0]),
                2 => @intCast(CodePointType, std.unicode.utf8Decode2(slice) catch unreachable),
                3 => @intCast(CodePointType, std.unicode.utf8Decode3(slice) catch unreachable),
                4 => @intCast(CodePointType, std.unicode.utf8Decode4(slice) catch unreachable),
                else => unreachable,
            };

            return it.c;
        }

        /// Look ahead at the next n codepoints without advancing the iterator.
        /// If fewer than n codepoints are available, then return the remainder of the string.
        pub fn peek(it: *Iterator, n: usize) []const u8 {
            const original_i = it.i;
            defer it.i = original_i;

            var end_ix = original_i;
            var found: usize = 0;
            while (found < n) : (found += 1) {
                const next_codepoint = it.nextCodepointSlice() orelse return it.bytes[original_i..];
                end_ix += next_codepoint.len;
            }

            return it.bytes[original_i..end_ix];
        }
    };
}

pub const CodepointIterator = NewCodePointIterator(CodePoint, -1);
pub const UnsignedCodepointIterator = NewCodePointIterator(u32, 0);

pub fn NewLengthSorter(comptime Type: type, comptime field: string) type {
    return struct {
        const LengthSorter = @This();
        pub fn lessThan(_: LengthSorter, lhs: Type, rhs: Type) bool {
            return @field(lhs, field).len < @field(rhs, field).len;
        }
    };
}

/// Update all strings in a struct pointing to "from" to point to "to".
pub fn moveAllSlices(comptime Type: type, container: *Type, from: string, to: string) void {
    const fields_we_care_about = comptime brk: {
        var count: usize = 0;
        for (std.meta.fields(Type)) |field| {
            if (std.meta.trait.isSlice(field.field_type) and std.meta.Child(field.field_type) == u8) {
                count += 1;
            }
        }

        var fields: [count][]const u8 = undefined;
        count = 0;
        for (std.meta.fields(Type)) |field| {
            if (std.meta.trait.isSlice(field.field_type) and std.meta.Child(field.field_type) == u8) {
                fields[count] = field.name;
                count += 1;
            }
        }
        break :brk fields;
    };

    inline for (fields_we_care_about) |name| {
        const slice = @field(container, name);
        if ((@ptrToInt(from.ptr) + from.len) >= @ptrToInt(slice.ptr) + slice.len and
            (@ptrToInt(from.ptr) <= @ptrToInt(slice.ptr)))
        {
            @field(container, name) = moveSlice(slice, from, to);
        }
    }
}

pub fn moveSlice(slice: string, from: string, to: string) string {
    std.debug.assert(from.len <= to.len and from.len >= slice.len);

    if (comptime Environment.allow_assert) {
        // assert we are in bounds
        std.debug.assert(
            (@ptrToInt(from.ptr) + from.len) >=
                @ptrToInt(slice.ptr) + slice.len and
                (@ptrToInt(from.ptr) <= @ptrToInt(slice.ptr)),
        );

        std.debug.assert(eqlLong(from, to[0..from.len], false)); // data should be identical
    }

    const ptr_offset = @ptrToInt(slice.ptr) - @ptrToInt(from.ptr);
    const result = to[ptr_offset..][0..slice.len];

    if (comptime Environment.allow_assert) {
        std.debug.assert(eqlLong(slice, result, false)); // data should be identical
    }

    return result;
}

test "moveSlice" {
    var input: string = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz";
    var cloned = try std.heap.page_allocator.dupe(u8, input);

    var slice = input[20..][0..10];

    try std.testing.expectEqual(eqlLong(moveSlice(slice, input, cloned), slice, false), true);
}

test "moveAllSlices" {
    const Move = struct {
        foo: string,
        bar: string,
        baz: string,
        wrong: string,
    };
    var input: string = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz";
    var move = Move{ .foo = input[20..], .bar = input[30..], .baz = input[10..20], .wrong = "baz" };
    var cloned = try std.heap.page_allocator.dupe(u8, input);
    moveAllSlices(Move, &move, input, cloned);
    var expected = Move{ .foo = cloned[20..], .bar = cloned[30..], .baz = cloned[10..20], .wrong = "bar" };
    try std.testing.expectEqual(move.foo.ptr, expected.foo.ptr);
    try std.testing.expectEqual(move.bar.ptr, expected.bar.ptr);
    try std.testing.expectEqual(move.baz.ptr, expected.baz.ptr);
    try std.testing.expectEqual(move.foo.len, expected.foo.len);
    try std.testing.expectEqual(move.bar.len, expected.bar.len);
    try std.testing.expectEqual(move.baz.len, expected.baz.len);
    try std.testing.expect(move.wrong.ptr != expected.wrong.ptr);
}

test "join" {
    var string_list = &[_]string{ "abc", "def", "123", "hello" };
    const list = try join(string_list, "-", std.heap.page_allocator);
    try std.testing.expectEqualStrings("abc-def-123-hello", list);
}

test "sortAsc" {
    var string_list = [_]string{ "abc", "def", "123", "hello" };
    var sorted_string_list = [_]string{ "123", "abc", "def", "hello" };
    var sorted_join = try join(&sorted_string_list, "-", std.heap.page_allocator);
    sortAsc(&string_list);
    var string_join = try join(&string_list, "-", std.heap.page_allocator);

    try std.testing.expectEqualStrings(sorted_join, string_join);
}

test "sortDesc" {
    var string_list = [_]string{ "abc", "def", "123", "hello" };
    var sorted_string_list = [_]string{ "hello", "def", "abc", "123" };
    var sorted_join = try join(&sorted_string_list, "-", std.heap.page_allocator);
    sortDesc(&string_list);
    var string_join = try join(&string_list, "-", std.heap.page_allocator);

    try std.testing.expectEqualStrings(sorted_join, string_join);
}

pub usingnamespace @import("exact_size_matcher.zig");

pub const unicode_replacement = 0xFFFD;
pub const unicode_replacement_str = brk: {
    var out: [std.unicode.utf8CodepointSequenceLength(unicode_replacement) catch unreachable]u8 = undefined;
    _ = std.unicode.utf8Encode(unicode_replacement, &out) catch unreachable;
    break :brk out;
};

test "eqlCaseInsensitiveASCII" {
    try std.testing.expect(eqlCaseInsensitiveASCII("abc", "ABC", true));
    try std.testing.expect(eqlCaseInsensitiveASCII("abc", "abc", true));
    try std.testing.expect(eqlCaseInsensitiveASCII("aBcD", "aBcD", true));
    try std.testing.expect(!eqlCaseInsensitiveASCII("aBcD", "NOOO", true));
    try std.testing.expect(!eqlCaseInsensitiveASCII("aBcD", "LENGTH CHECK", true));
}
