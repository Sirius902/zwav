const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const StreamSource = std.io.StreamSource;
const Endian = std.builtin.Endian;

pub const Wav = struct {
    stream: StreamSource,
    data_start: u64,
    data_end: u64,
    pos: u64,
    header: Header,

    pub const ReadError = StreamSource.ReadError;
    pub const SeekError = StreamSource.SeekError;
    pub const GetSeekPosError = error{};
    pub const Reader = std.io.Reader(*Wav, ReadError, read);

    pub fn init(stream: StreamSource) (StreamError || error{EndOfStream} || Error)!Wav {
        var s = stream;
        var header = try s.reader().readStructEndian(Header, .little);
        // These fields are strings so they should always stay in the same byte order.
        if (builtin.cpu.arch.endian() == .big) {
            header.chunk_id = @byteSwap(header.chunk_id);
            header.format = @byteSwap(header.format);
            header.subchunk1_id = @byteSwap(header.subchunk1_id);
            header.subchunk2_id = @byteSwap(header.subchunk2_id);
        }

        if (header.chunk_id != wav_chunk_id) return error.InvalidWavHeader;
        if (header.format != wav_format) return error.InvalidWavHeader;

        if (header.subchunk1_id != wav_subchunk1_id) return error.InvalidWavHeader;
        if (header.subchunk1_size != 16) return error.UnsupportedWav;
        // Only uncompressed PCM audio is supported.
        if (header.audio_format != 1) return error.UnsupportedWav;

        if (header.subchunk2_id != wav_subchunk2_id) return error.InvalidWavHeader;

        const data_start = try s.getPos();
        return .{
            .stream = s,
            .data_start = data_start,
            .data_end = data_start + header.subchunk2_size,
            .pos = data_start,
            .header = header,
        };
    }

    pub fn dataSize(self: Wav) usize {
        return self.header.subchunk2_size;
    }

    pub fn read(self: *Wav, dest: []u8) ReadError!usize {
        const len = @min(dest.len, self.data_end - self.pos);
        const read_len = try self.stream.read(dest[0..len]);
        self.pos += read_len;
        return read_len;
    }

    pub fn seekTo(self: *Wav, pos: u64) SeekError!void {
        const new_pos = @min(self.data_start + pos, self.data_end);
        try self.stream.seekTo(new_pos);
        self.pos = new_pos;
    }

    pub fn seekBy(self: *Wav, amt: i64) SeekError!void {
        if (amt < 0) {
            const abs_amt = @abs(amt);
            const abs_amt_usize = std.math.cast(usize, abs_amt) orelse std.math.maxInt(usize);
            if (abs_amt_usize > self.pos - self.data_start) {
                self.pos = self.data_start;
            } else {
                self.pos -= abs_amt_usize;
            }
        } else {
            const amt_usize = std.math.cast(usize, amt) orelse std.math.maxInt(usize);
            const new_pos = std.math.add(usize, self.pos, amt_usize) catch std.math.maxInt(usize);
            self.pos = @min(self.data_end, new_pos);
        }

        try self.stream.seekTo(self.pos);
    }

    pub fn getEndPos(self: *Wav) GetSeekPosError!u64 {
        return self.data_end - self.data_start;
    }

    pub fn getPos(self: *Wav) GetSeekPosError!u64 {
        return self.pos - self.data_start;
    }

    pub fn reader(self: *Wav) Reader {
        return .{ .context = self };
    }
};

pub const StreamError = StreamSource.ReadError || StreamSource.SeekError;

pub const Error = error{
    InvalidWavHeader,
    UnsupportedWav,
};

const wav_chunk_id = magicInt("RIFF");
const wav_format = magicInt("WAVE");
const wav_subchunk1_id = magicInt("fmt ");
const wav_subchunk2_id = magicInt("data");

pub const Header = extern struct {
    chunk_id: u32 = wav_chunk_id,
    chunk_size: u32,
    format: u32 = wav_format,
    subchunk1_id: u32 = wav_subchunk1_id,
    subchunk1_size: u32,
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
    subchunk2_id: u32 = wav_subchunk2_id,
    subchunk2_size: u32,
};

fn magicInt(magic: *const [4]u8) u32 {
    return @bitCast(magic.*);
}

test "Header is correct size" {
    try testing.expectEqual(44, @sizeOf(Header));
}
