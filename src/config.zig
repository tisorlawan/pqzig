const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const OpenAIConfig = struct {
    api_key: []const u8,
    api_base: []const u8,
    api_type: []const u8,
    embedding_deployment: []const u8,
    chat_deployment: []const u8,
    api_version: []const u8,

    pub fn deinit(self: *const OpenAIConfig, allocator: Allocator) void {
        allocator.free(self.api_key);
        allocator.free(self.api_base);
        allocator.free(self.api_type);
        allocator.free(self.embedding_deployment);
        allocator.free(self.chat_deployment);
        allocator.free(self.api_version);
    }
};

pub const QdrantConfig = struct {
    url: []const u8,
    collection_name: []const u8,
    api_key: ?[]const u8,

    pub fn deinit(self: *const QdrantConfig, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.collection_name);
        if (self.api_key) |key| {
            allocator.free(key);
        }
    }
};

pub const JinaConfig = struct {
    api_key: []const u8,
    rerank_url: []const u8,
    model: []const u8,

    pub fn deinit(self: *const JinaConfig, allocator: Allocator) void {
        allocator.free(self.api_key);
        allocator.free(self.rerank_url);
        allocator.free(self.model);
    }
};

pub const Config = struct {
    allocator: Allocator,

    database_url: []const u8,
    openai: OpenAIConfig,
    qdrant: QdrantConfig,
    jina: JinaConfig,
    default_scenario: []const u8,
    reranker_score_threshold: f64,
    reranker_top_k: u8,

    const Self = @This();

    const Error = error{
        EnvVarNotFound,
        InvalidFloatValue,
        InvalidIntValue,
        OutOfMemory,
    };

    /// Will exit the program if there is something wrong
    pub fn initFromEnv(allocator: Allocator) Self {
        const getEnvOrExit = struct {
            fn inner(alloc: Allocator, key: []const u8) []const u8 {
                return std.process.getEnvVarOwned(alloc, key) catch {
                    std.debug.print("[E] Environment variable: {s} is not found\n", .{key});
                    std.process.exit(1);
                };
            }
        }.inner;

        const getEnvOptional = struct {
            fn inner(alloc: Allocator, key: []const u8) ?[]const u8 {
                return std.process.getEnvVarOwned(alloc, key) catch {
                    return null;
                };
            }
        }.inner;

        return Config{
            .allocator = allocator,
            .database_url = getEnvOrExit(allocator, "DATABASE_URL"),
            .openai = OpenAIConfig{
                .api_key = getEnvOrExit(allocator, "OPENAI_API_KEY"),
                .api_base = getEnvOrExit(allocator, "OPENAI_API_BASE"),
                .api_type = getEnvOrExit(allocator, "OPENAI_API_TYPE"),
                .embedding_deployment = getEnvOrExit(allocator, "OPENAI_EMBEDDING_DEPLOYMENT_NAME"),
                .chat_deployment = getEnvOrExit(allocator, "OPENAI_CHAT_DEPLOYMENT_NAME"),
                .api_version = getEnvOrExit(allocator, "OPENAI_API_VERSION"),
            },
            .qdrant = QdrantConfig{
                .url = getEnvOrExit(allocator, "QDRANT_URL"),
                .collection_name = getEnvOrExit(allocator, "QDRANT_COLLECTION_NAME"),
                .api_key = getEnvOptional(allocator, "QDRANT_API_KEY"),
            },
            .jina = JinaConfig{
                .api_key = getEnvOrExit(allocator, "JINA_API_KEY"),
                .rerank_url = getEnvOrExit(allocator, "JINA_RERANK_URL"),
                .model = getEnvOrExit(allocator, "JINA_MODEL"),
            },
            .default_scenario = getEnvOrExit(allocator, "DEFAULT_SCENARIO"),
            .reranker_score_threshold = blk: {
                const threshold_str = getEnvOrExit(allocator, "RERANKER_SCORE_THRESHOLD");
                defer allocator.free(threshold_str);
                const threshold = std.fmt.parseFloat(f64, threshold_str) catch {
                    std.debug.print("[E] cannot parse RERANKER_SCORE_THRESHOLD as float\n", .{});
                    std.process.exit(1);
                };
                if (threshold < 0.0 or threshold > 1.0) {
                    std.debug.print("[E] RERANKER_SCORE_THRESHOLD must be >= 0.0 and <= 1.0\n", .{});
                    std.process.exit(1);
                }
                break :blk threshold;
            },
            .reranker_top_k = blk: {
                const top_k_str = getEnvOrExit(allocator, "RERANKER_TOP_K");
                defer allocator.free(top_k_str);
                const top_k = std.fmt.parseInt(u8, top_k_str, 10) catch {
                    std.debug.print("[E] cannot parse RERANKER_TOP_K as u8\n", .{});
                    std.process.exit(1);
                };
                if (top_k == 0) {
                    std.debug.print("[E] RERANKER_TOP_K must be > 0\n", .{});
                    std.process.exit(1);
                }
                break :blk top_k;
            },
        };
    }

    pub fn deinit(self: *const Config) void {
        self.allocator.free(self.database_url);
        self.openai.deinit(self.allocator);
        self.qdrant.deinit(self.allocator);
        self.jina.deinit(self.allocator);
        self.allocator.free(self.default_scenario);
    }
};

// TODO: add testing
