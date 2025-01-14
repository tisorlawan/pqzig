const std = @import("std");
const Config = @import("./config.zig").Config;
const logging = @import("./logging.zig");
const db = @import("./db.zig");
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

    // Configuration
    var config = Config.initFromEnv(allocator);
    defer config.deinit();

    const file = try std.fs.createFileAbsolute("/tmp/zig.log", .{});
    defer file.close();
    var logger = logging.getGlobalLogger().?;

    const conn = db.connect("postgresql://user:password@localhost:5432/test");
    defer db.finish(conn);

    logger.info("Connected to postgresql: {}", .{pq.PQsocket(conn)});

    {
        const pqRes = pq.PQexec(conn,
            \\ CREATE TABLE IF NOT EXISTS users (
            \\     id SERIAL PRIMARY KEY, 
            \\     name VARCHAR(100), 
            \\     active BOOLEAN DEFAULT true
            \\ );
        );
        defer pq.PQclear(pqRes);

        if (pq.PQresultStatus(pqRes) != pq.PGRES_COMMAND_OK) {
            logger.err("{s}", .{pq.PQerrorMessage(conn)});
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
        const pq_res = pq.PQexec(conn,
            \\ SELECT * FROM users ORDER BY name DESC
        );
        defer pq.PQclear(pq_res);

        const status = pq.PQresultStatus(pq_res);
        if (status != pq.PGRES_TUPLES_OK) {
            logger.err("{s} => {s}", .{ pq.PQresStatus(status), pq.PQerrorMessage(conn) });
        } else {
            const users = try db.ParseList(User).do(allocator, pq_res.?);

            defer users.deinit();
            for (users.items) |user| {
                std.debug.print("{} [{}] - {s}\n", .{ user.id, user.active, user.name });
            }
        }
    }
}
