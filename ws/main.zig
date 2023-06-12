const std = @import("std");
const alloc = std.heap.wasm_allocator;

export fn jsAlloc(size: usize) ?[*]u8 {
    return (alloc.alloc(u8, size) catch return null).ptr;
}
export fn jsFree(ptr: [*]u8, size: usize) void {
    alloc.free(ptr[0..size]);
}
extern fn setInfo(ptr: [*]const u8, len: usize) void;
extern fn setPict(ptr: [*]const u8, len: usize) void;
extern fn setData(ptr: [*]const u8, len: usize) void;
extern fn showErr(ptr: [*]const u8, len: usize) void;

fn Slice(comptime T: anytype) type {
    return struct {
        const Self = @This();
        left: T,
        pub fn take(self: *Self, n: anytype) error{EOF}!@TypeOf(self.left[0..n]) {
            if (self.left.len < n) return error.EOF;
            defer self.left = self.left[n..];
            return self.left[0..n];
        }
    };
}

export fn process(ptr: [*]u8, len: usize) i32 {
    realProcess(ptr[0..len]) catch |e| {
        const s = @errorName(e);
        showErr(s.ptr, s.len);
        return -1;
    };
    return 0;
}

fn realProcess(bytes: []u8) !void {
    var r = Slice([]u8){ .left = bytes };
    if (!std.mem.eql(u8, "CTENFDAM", (try r.take(10))[0..8])) return error.NotNCM;
    const kl = std.mem.readIntLittle(u32, try r.take(4));
    const kd = try r.take(kl);
    const kbox = try makeKeyBox(kd);
    const il = std.mem.readIntLittle(u32, try r.take(4));
    const id = try r.take(il);
    const info = try getInfo(id);
    _ = try r.take(9);
    const plen = std.mem.readIntLittle(u32, try r.take(4));
    const pict = try r.take(plen);
    const data = r.left;
    for (data, 0..) |*b, i| {
        const j = (i + 1) & 0xff;
        const k = (kbox[j] + j) & 0xff;
        b.* ^= kbox[kbox[j] +% kbox[k]];
    }
    setInfo(info.ptr, info.len);
    setPict(pict.ptr, pict.len);
    setData(data.ptr, data.len);
}

const HEAD_KEY = [_]u8{ 0x68, 0x7A, 0x48, 0x52, 0x41, 0x6D, 0x73, 0x6F, 0x35, 0x6B, 0x49, 0x6E, 0x62, 0x61, 0x78, 0x57 };
const INFO_KEY = [_]u8{ 0x23, 0x31, 0x34, 0x6C, 0x6A, 0x6B, 0x5F, 0x21, 0x5C, 0x5D, 0x26, 0x30, 0x55, 0x3C, 0x27, 0x28 };

fn makeKeyBox(kd: []u8) ![256]u8 {
    if (kd.len < 32 or kd.len % 16 != 0) return error.KeyLen;
    for (kd) |*b| b.* ^= 0x64;
    const a = std.crypto.core.aes.Aes128.initDec(HEAD_KEY);
    var buf: [272]u8 = undefined;
    if (kd.len > 288) a.decryptWide(17, &buf, kd[16..288]) else {
        for (
            @ptrCast([*][16]u8, &buf),
            @ptrCast([*][16]u8, kd)[1 .. kd.len / 16],
        ) |*d, *s| a.decrypt(d, s);
        const j = try std.math.sub(usize, kd.len - 16, buf[kd.len - 17]);
        if (j < 257) {
            for (buf[j..257], buf[1 .. 258 - j]) |*d, s| d.* = s;
        }
    }
    var lb: u8 = 0;
    var kb: [256]u8 = undefined;
    for (0..256) |i| kb[i] = @intCast(u8, i);
    for (0..256, buf[1..257]) |i, j| {
        lb = @truncate(u8, @as(u16, kb[i]) + lb + j);
        std.mem.swap(u8, &kb[i], &kb[lb]);
    }
    return kb;
}

fn getInfo(id: []u8) ![]const u8 {
    for (id) |*b| b.* ^= 0x63;
    var d = std.base64.standard.Decoder;
    const db = id[0..try d.calcSizeForSlice(id[22..])];
    if (db.len % 16 != 0) return error.InfLen;
    try d.decode(db, id[22..]);
    const aes = std.crypto.core.aes.Aes128.initDec(INFO_KEY);
    for (@ptrCast([*][16]u8, db)[0 .. db.len / 16]) |*b| aes.decrypt(b, b);
    const end = try std.math.sub(usize, db.len, db[db.len - 1]);
    return db[0..end];
}
