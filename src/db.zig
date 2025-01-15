const std = @import("std");
const pq = @cImport({
    @cInclude("libpq-fe.h");
});
const logging = @import("./logging.zig");
const types = @import("./types.zig");

fn DBItems(comptime T: type) type {
    return struct {
        pg_res: *pq.PGresult,
        _items: std.ArrayList(T),

        const Self = @This();

        fn new(pg_res: *pq.PGresult, mitems: std.ArrayList(T)) Self {
            return Self{
                .pg_res = pg_res,
                ._items = mitems,
            };
        }

        pub fn deinit(self: *const Self) void {
            self._items.deinit();
            pq.PQclear(self.pg_res);
        }

        pub fn items(self: *const Self) []const T {
            return self._items.items;
        }
    };
}

pub const DB = struct {
    allocator: std.mem.Allocator,
    conn: *pq.PGconn,
    logger: *logging.Logger,

    pub fn init(
        allocator: std.mem.Allocator,
        connection_uri: [*c]const u8,
        logger: *logging.Logger,
    ) DB {
        var db = DB{ .allocator = allocator, .conn = undefined, .logger = logger };
        db.conn = db.connect(connection_uri);
        return db;
    }

    pub fn deinit(self: *const DB) void {
        pq.PQfinish(self.conn);
    }

    // TODO: add internal retry mechanism
    /// Panic if connection failed.
    fn connect(self: *DB, connection_uri: [*c]const u8) *pq.PGconn {
        const conn_res = pq.PQconnectdb(connection_uri);
        const conn_status = pq.PQstatus(conn_res);

        if (conn_status != pq.CONNECTION_OK) {
            const error_message = pq.PQerrorMessage(conn_res);
            self.logger.err("{s}", .{error_message});
            std.debug.panic("Can't connect to db: '{s}'", .{connection_uri});
        }

        self.logger.info("Connected to postgresql: {}", .{pq.PQsocket(conn_res.?)});
        return conn_res.?;
    }

    pub fn fetchList(
        self: *const DB,
        comptime T: type,
        allocator: std.mem.Allocator,
        query: [*c]const u8,
    ) !DBItems(T) {
        const pq_res = pq.PQexec(self.conn, query);
        if (pq_res == null) return error.QueryFailed;

        const status = pq.PQresultStatus(pq_res);
        if (status != pq.PGRES_TUPLES_OK) {
            self.logger.err("{s} => {s}", .{ pq.PQresStatus(status), pq.PQerrorMessage(self.conn) });
            return error.QueryFailed;
        } else {
            const users = try DB.ParseList(T).do(allocator, pq_res.?);
            return DBItems(T).new(pq_res.?, users);
        }
    }

    fn ParseList(comptime T: type) type {
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
                        const dtype = pq.PQftype(res, map.get(field.name).?);
                        switch (field.type) {
                            []const u8 => {
                                if (dtype == types.BPCHAR_OID or dtype == types.VARCHAR_OID or dtype == types.TEXT_OID) {
                                    const value = parseStr(res, row, map.get(field.name).?);
                                    @field(item, field.name) = value;
                                } else {
                                    std.debug.print("Invalid db type for field '{s}' which has type '{}'.\n", .{ field.name, field.type });
                                    return error.InvalidType;
                                }
                            },
                            u64 => {
                                if (dtype == types.INT2_OID or dtype == types.INT4_OID or dtype == types.INT8_OID or dtype == types.NUMERIC_OID) {
                                    const value = try parseInt(u64, res, row, map.get(field.name).?);
                                    @field(item, field.name) = value;
                                } else {
                                    std.debug.print("Invalid db type for field '{s}' which has type '{}'.\n", .{ field.name, field.type });
                                    return error.InvalidType;
                                }
                            },
                            bool => {
                                if (dtype == types.BOOL_OID) {
                                    const value = parseBool(res, row, map.get(field.name).?);
                                    @field(item, field.name) = value;
                                } else {
                                    std.debug.print("Invalid db type for field '{s}' which has type '{}'.\n", .{ field.name, field.type });
                                    return error.InvalidType;
                                }
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
};

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
