const std = @import("std");
const zwav = @import("zwav");

const test_wav: []const u8 = @embedFile("sound/test.wav");

pub fn main() !void {
    var wav = try zwav.Wav.init(.{ .const_buffer = std.io.fixedBufferStream(test_wav) });
    std.log.info("Chunk Id: {s}", .{@as([4]u8, @bitCast(wav.header.chunk_id))});
    std.log.info("Chunk Size: {}", .{wav.header.chunk_size});
    std.log.info("Format: {s}", .{@as([4]u8, @bitCast(wav.header.format))});
    std.log.info("Subchunk1 Id: {s}", .{@as([4]u8, @bitCast(wav.header.subchunk1_id))});
    std.log.info("Subchunk1 Size: {}", .{wav.header.subchunk1_size});
    std.log.info("Subchunk2 Id: {s}", .{@as([4]u8, @bitCast(wav.header.subchunk2_id))});
    std.log.info("Subchunk2 Size: {}", .{wav.header.subchunk2_size});
    std.log.info("Data span: [{}, {})", .{ wav.data_start, wav.data_end });

    std.log.info("Pos: {}", .{try wav.getPos()});
    std.log.info("End pos: {}", .{try wav.getEndPos()});
    std.log.info("Stream pos: {}", .{try wav.stream.getPos()});
    std.log.info("Stream end pos: {}", .{try wav.stream.getEndPos()});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const audio_data = try wav.reader().readAllAlloc(allocator, wav.dataSize());
    defer allocator.free(audio_data);

    std.log.info("Audio data size: {}", .{audio_data.len});
}
