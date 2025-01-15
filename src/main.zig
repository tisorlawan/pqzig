const std = @import("std");
const logging = @import("./logging.zig");
const DB = @import("./db.zig").DB;
const pq = @cImport({
    @cInclude("libpq-fe.h");
});

const MyEnum = enum { a, b };

const User = struct {
    id: u64,
    name: []const u8,
    active: bool,
};

pub fn main() !void {
    logging.initGlobalLogger(.{ .min_level = .debug });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.createFileAbsolute("/tmp/zig.log", .{});
    defer file.close();
    var logger = logging.getGlobalLogger().?;

    const db = DB.init(
        allocator,
        "postgresql://user:password@localhost:5432/test",
        logger,
    );
    defer db.deinit();

    {
        const pqRes = pq.PQexec(db.conn,
            \\ CREATE TABLE IF NOT EXISTS users (
            \\     id SERIAL PRIMARY KEY, 
            \\     name VARCHAR(100), 
            \\     active BOOLEAN DEFAULT true
            \\ );
        );
        defer pq.PQclear(pqRes);

        if (pq.PQresultStatus(pqRes) != pq.PGRES_COMMAND_OK) {
            logger.err("{s}", .{pq.PQerrorMessage(db.conn)});
        } else {
            logger.info("Command successfully executed.", .{});
        }
    }

    // pqRes = pq.PQexec(conn,
    //     \\ INSERT INTO users
    //     \\     (name, active)
    //     \\ VALUES
    //     \\     ('Charlie', true);
    // );
    // if (pq.PQresultStatus(pqRes) != pq.PGRES_COMMAND_OK) {
    //     logger.err("{s}", .{pq.PQerrorMessage(conn)});
    // } else {
    //     logger.info("Insert command executed successfully", .{});
    // }

    {
        const users = try db.fetchList(User, allocator, "SELECT * FROM users ORDER BY name DESC");
        defer users.deinit();

        for (users.items()) |user| {
            std.debug.print("{} [{}] - {s}\n", .{ user.id, user.active, user.name });
        }
    }
    std.debug.print("=================================\n", .{});
    {
        const users = try db.fetchList(User, allocator, "SELECT * FROM users ORDER BY name ASC");
        defer users.deinit();

        for (users.items()) |user| {
            std.debug.print("{} [{}] - {s}\n", .{ user.id, user.active, user.name });
        }
    }
}
