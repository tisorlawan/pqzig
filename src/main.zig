const std = @import("std");
const Config = @import("./config.zig").Config;
const logging = @import("./logging.zig");

pub fn main() !void {
    logging.initGlobalLogger(.{ .min_level = .debug });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configuration
    var config = Config.initFromEnv(allocator);
    defer config.deinit();

    const file = try std.fs.createFileAbsolute("/tmp/zig.log", .{});
    defer file.close();
    var logger = logging.getGlobalLogger().?;

    logger.debug("{s}", .{"Test debug"});
    logger.info("{s}", .{"Test info"});
    logger.warn("{s}", .{"Test warn"});
    logger.err("{s}", .{"Test error"});
}
