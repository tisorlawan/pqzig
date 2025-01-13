const std = @import("std");
const pq = @cImport({
    @cInclude("libpq-fe.h");
});
const logging = @import("./logging.zig");

// TODO: add internal retry mechanism
/// Panic if connection failed.
pub fn connect(connection_uri: [*c]const u8) *pq.PGconn {
    const logger = logging.getGlobalLogger().?;

    const conn_res = pq.PQconnectdb(connection_uri);
    const conn_status = pq.PQstatus(conn_res);

    if (conn_status != pq.CONNECTION_OK) {
        const error_message = pq.PQerrorMessage(conn_res);
        logger.err("{s}", .{error_message});
        std.debug.panic("Can't connect to db: '{s}'", .{connection_uri});
    }

    return conn_res.?;
}

pub fn finish(conn: *pq.PGconn) void {
    pq.PQfinish(conn);
}
