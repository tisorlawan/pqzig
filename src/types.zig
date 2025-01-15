pub const Oid = c_uint;

// Boolean
pub const BOOL_OID: Oid = 16;

// Numbers
pub const INT2_OID: Oid = 21; // smallint
pub const INT4_OID: Oid = 23; // integer
pub const INT8_OID: Oid = 20; // bigint
pub const FLOAT4_OID: Oid = 700; // real
pub const FLOAT8_OID: Oid = 701; // double precision
pub const NUMERIC_OID: Oid = 1700;

// Character Types
pub const BPCHAR_OID: Oid = 1042; // char(n)
pub const VARCHAR_OID: Oid = 1043; // varchar(n)
pub const TEXT_OID: Oid = 25; // text

// Date/Time
pub const DATE_OID: Oid = 1082; // date
pub const TIME_OID: Oid = 1083; // time without timezone
pub const TIMETZ_OID: Oid = 1266; // time with timezone
pub const TIMESTAMP_OID: Oid = 1114; // timestamp without timezone
pub const TIMESTAMPTZ_OID: Oid = 1184; // timestamp with timezone

// Binary
pub const BYTEA_OID: Oid = 17;

// JSON
pub const JSON_OID: Oid = 114;
pub const JSONB_OID: Oid = 3802;

// Arrays of basic types
pub const INT2_ARRAY_OID: Oid = 1005;
pub const INT4_ARRAY_OID: Oid = 1007;
pub const INT8_ARRAY_OID: Oid = 1016;
pub const TEXT_ARRAY_OID: Oid = 1009;
pub const BYTEA_ARRAY_OID: Oid = 1001;
pub const VARCHAR_ARRAY_OID: Oid = 1015;
pub const TIMESTAMP_ARRAY_OID: Oid = 1115;
pub const TIMESTAMPTZ_ARRAY_OID: Oid = 1185;

// UUID
pub const UUID_OID: Oid = 2950;

// Special
pub const VOID_OID: Oid = 2278;
pub const UNKNOWN_OID: Oid = 705;
