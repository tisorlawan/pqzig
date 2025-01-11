const std = @import("std");
const Headers = @import("std").http.Client.Request.Headers;
const RequestOptions = @import("std").http.Client.RequestOptions;
const Client = @import("std").http.Client;

const RERANKER_API_KEY = "jina_ae389feeac554dea93297f9afd32cc2583fmfPfLMsBGmUzUCawX_Zj021mR";
const RERANKER_URI = "https://api.jina.ai/v1/rerank";
const RERANKER_HEADERS = Headers{
    .content_type = Headers.Value{ .override = "application/json" },
    .authorization = Headers.Value{ .override = "Bearer " ++ RERANKER_API_KEY },
};

const RerankerInput = struct {
    model: []const u8 = "jina-reranker-v2-base-multilingual",
    query: []const u8,
    top_n: u8,
    documents: []const []const u8,
};

const RerankerOutput = struct {
    model: []const u8,
    usage: struct {
        total_tokens: u64,
    },
    results: []const struct {
        index: u16,
        document: struct {
            text: []const u8,
        },
        relevance_score: f64,
    },
};

pub fn reranker(arena: *std.heap.ArenaAllocator, query: []const u8, documents: []const []const u8, top_n: u8) !RerankerOutput {
    var allocator = arena.allocator();

    const uri = try std.Uri.parse(RERANKER_URI);
    var client = Client{ .allocator = allocator };
    var req = try client.open(.POST, uri, RequestOptions{
        .headers = RERANKER_HEADERS,
        .server_header_buffer = try allocator.alloc(u8, 8 * 1024 * 4),
    });
    req.transfer_encoding = .chunked;

    const body = RerankerInput{
        .query = query,
        .top_n = top_n,
        .documents = documents,
    };

    var json_string = std.ArrayList(u8).init(allocator);
    try std.json.stringify(body, .{}, json_string.writer());

    try req.send();
    try req.writeAll(json_string.items);
    try req.finish();
    try req.wait();

    const json_str = try req.reader().readAllAlloc(allocator, 128_000_000);
    const response = try std.json.parseFromSliceLeaky(RerankerOutput, allocator, json_str, .{});
    return response;
}

test "wow" {
    try std.testing.expect(1 == 1);
}
