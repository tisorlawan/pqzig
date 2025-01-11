const std = @import("std");

pub const LogLevel = enum(u8) {
    debug,
    info,
    warn,
    err,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }

    pub fn getColor(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
        };
    }
};

pub const LoggerConig = struct {
    min_level: LogLevel = .info,
    use_timestamp: bool = true,
    tz_offset: u8 = 7,
    use_color: bool = true,
};

pub const Logger = struct {
    config: LoggerConig,
    writer: std.fs.File.Writer,
    mutex: std.Thread.Mutex,
    is_file: bool = false,

    const Self = @This();

    pub fn init(config: LoggerConig) Self {
        return .{
            .config = config,
            .mutex = std.Thread.Mutex{},
            .writer = std.io.getStdOut().writer(),
            .is_file = false,
        };
    }

    pub fn initFile(config: LoggerConig, file: std.fs.File) Self {
        return .{
            .config = config,
            .mutex = std.Thread.Mutex{},
            .writer = file.writer(),
            .is_file = true,
        };
    }

    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }

    pub fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) >= @intFromEnum(self.config.min_level)) {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.config.use_color and !self.is_file) {
                self.writer.print("{s}", .{level.getColor()}) catch return;
            }

            // timestamp
            if (self.config.use_timestamp) {
                const timestamp = std.time.timestamp();
                const date = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };

                const year_day = date.getEpochDay().calculateYearDay();
                const month_day = date.getEpochDay().calculateYearDay().calculateMonthDay();

                self.writer.print(
                    "[{d:0>2}-{d:0>2}-{d:0>4} {d:0>2}:{d:0>2}:{d:0>2}]",
                    .{
                        month_day.day_index,
                        month_day.month.numeric(),
                        year_day.year,
                        date.getDaySeconds().getHoursIntoDay() + self.config.tz_offset,
                        date.getDaySeconds().getMinutesIntoHour(),
                        date.getDaySeconds().getSecondsIntoMinute(),
                    },
                ) catch return;
            }

            // level
            self.writer.print("[{s}] ", .{level.toString()}) catch return;

            if (self.config.use_color and !self.is_file) {
                self.writer.print("{s}", .{"\x1b[0m"}) catch return;
            }

            // message
            self.writer.print(fmt ++ "\n", args) catch return;
        }
    }
};

// Convenient global logger
var global_logger: ?Logger = null;

pub fn getGlobalLogger() ?*Logger {
    return if (global_logger) |*logger| logger else null;
}

pub fn initGlobalLogger(config: LoggerConig) void {
    global_logger = Logger.init(config);
}

test "Basic testing functionality" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const log_file_name = "test.log";
    _ = try tmp.dir.createFile(log_file_name, .{});

    const file = try tmp.dir.openFile(log_file_name, .{ .mode = .read_write });
    defer file.close();

    var logger = Logger.initFile(.{
        .min_level = .debug,
        .use_timestamp = false,
        .use_color = false,
    }, file);

    logger.debug("Debug message: {s}", .{"test"});
    logger.info("Info message: {s}", .{"test"});
    logger.warn("Warning message: {s}", .{"test"});
    logger.err("Error message: {s}", .{"test"});

    try file.seekTo(0);
    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[DEBUG] Debug message") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[INFO] Info message") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[WARN] Warning message") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[ERROR] Error message") != null);
}

test "Filtering functionality" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const log_file_name = "test.log";
    _ = try tmp.dir.createFile(log_file_name, .{});

    const file = try tmp.dir.openFile(log_file_name, .{ .mode = .read_write });
    defer file.close();

    var logger = Logger.initFile(.{
        .min_level = .warn,
        .use_timestamp = false,
        .use_color = false,
    }, file);

    logger.debug("Debug message: {s}", .{"test"});
    logger.info("Info message: {s}", .{"test"});
    logger.warn("Warning message: {s}", .{"test"});
    logger.err("Error message: {s}", .{"test"});

    try file.seekTo(0);
    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[DEBUG] Debug message") == null);
    try testing.expect(std.mem.indexOf(u8, content, "[INFO] Info message") == null);
    try testing.expect(std.mem.indexOf(u8, content, "[WARN] Warning message") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[ERROR] Error message") != null);
}
