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

pub fn ParseList(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct) {
            @compileError("parse expect a struct");
        }
    }

    return struct {
        const fields = @typeInfo(T).Struct.fields;

        pub fn do(allocator: std.mem.Allocator, res: *pq.PGresult) !std.ArrayList(T) {
            const n_fields = pq.PQnfields(res);
            const n_tuples = pq.PQntuples(res);

            var map = std.StringHashMap(c_int).init(allocator);
            defer map.deinit();
            for (0..@intCast(n_fields)) |c| {
                const col_name = pq.PQfname(res, @intCast(c));
                try map.put(std.mem.span(col_name), @intCast(c));
            }

            var list = std.ArrayList(T).init(allocator);
            for (0..@intCast(n_tuples)) |row| {
                var item: T = undefined;
                inline for (fields) |field| {
                    switch (field.type) {
                        []const u8 => {
                            const value = parseStr(res, row, map.get(field.name).?);
                            @field(item, field.name) = value;
                        },
                        u64 => {
                            const value = try parseInt(u64, res, row, map.get(field.name).?);
                            @field(item, field.name) = value;
                        },
                        bool => {
                            const value = parseBool(res, row, map.get(field.name).?);
                            @field(item, field.name) = value;
                        },
                        else => {
                            @compileError("Unsupported type: " ++ @typeName(field.type));
                        },
                    }
                }
                try list.append(item);
            }
            return list;
        }
    };
}

pub fn parseStr(res: *pq.PGresult, row_num: anytype, col_num: anytype) []const u8 {
    return std.mem.span(pq.PQgetvalue(res, @intCast(row_num), @intCast(col_num)));
}

pub fn parseInt(comptime T: type, res: *pq.PGresult, row_num: anytype, col_num: anytype) !T {
    const str = parseStr(res, row_num, col_num);
    return try std.fmt.parseInt(T, str, 10);
}

pub fn parseBool(res: *pq.PGresult, row_num: anytype, col_num: anytype) bool {
    const str = parseStr(res, row_num, col_num);
    return str[0] == 't';
}

pub fn finish(conn: *pq.PGconn) void {
    pq.PQfinish(conn);
}
