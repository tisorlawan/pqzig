const std = @import("std");
const Config = @import("./config.zig").Config;
const logging = @import("./logging.zig");
const db = @import("./db.zig");
const pq = @cImport({
    @cInclude("libpq-fe.h");
});

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
        const pqRes = pq.PQexec(conn,
            \\ SELECT * FROM users;
        );
        defer pq.PQclear(pqRes);

        const status = pq.PQresultStatus(pqRes);
        if (status != pq.PGRES_TUPLES_OK) {
            logger.err("{s} => {s}", .{ pq.PQresStatus(status), pq.PQerrorMessage(conn) });
        } else {
            const n_tuples = pq.PQntuples(pqRes);
            const n_fields = pq.PQnfields(pqRes);
            logger.info(
                \\ Select command executed successfully: 
                \\ - N Rows  : {}
                \\ - N Fields: {}
            , .{ n_tuples, n_fields });

            logger.info("Column names:", .{});
            for (0..@as(usize, @intCast(n_fields))) |i| {
                const col_name = pq.PQfname(pqRes, @as(c_int, @intCast(i)));
                std.debug.print(" - Col {} = {s}\n", .{ i, col_name });
            }
        }
    }
}
