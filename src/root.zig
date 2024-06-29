const std = @import("std");
const testing = std.testing;

pub const GitHubClient = struct {
    pub const PullRequest = struct {
        const State = enum { open, closed };
        id: u64,
        url: []const u8,
        diff_url: []const u8,
        state: State,
        title: []const u8,
    };

    accessToken: []const u8, // owned

    _a: std.mem.Allocator,
    _client: *std.http.Client, // not owned

    pub fn init(a: std.mem.Allocator, client: *std.http.Client) !GitHubClient {
        const accessToken = try std.process.getEnvVarOwned(a, "GH_PRTOOl_ACCESS_TOKEN");
        return .{
            .accessToken = accessToken,
            ._a = a,
            ._client = client,
        };
    }

    pub fn deinit(self: *GitHubClient) void {
        self._a.free(self.accessToken);
    }

    pub fn listPullRequests(self: *GitHubClient, owner: []const u8, repo: []const u8) !std.json.Parsed([]PullRequest) {
        // curl -L \
        // -H "Accept: application/vnd.github+json" \
        // -H "Authorization: Bearer <YOUR-TOKEN>" \
        // -H "X-GitHub-Api-Version: 2022-11-28" \
        // https://api.github.com/repos/OWNER/REPO/pulls
        const url = try std.fmt.allocPrint(self._a, "https://api.github.com/repos/{s}/{s}/pulls", .{ owner, repo });
        defer self._a.free(url);
        const bearer = try std.fmt.allocPrint(self._a, "Bearer {s}", .{self.accessToken});
        defer self._a.free(bearer);
        var response_buf = std.ArrayList(u8).init(self._a);
        defer response_buf.deinit();
        var header_buf = [_]u8{0} ** 4096;
        const response = try self._client.fetch(.{
            .location = .{ .url = url },
            .response_storage = .{ .dynamic = &response_buf },
            .server_header_buffer = &header_buf,
            .extra_headers = &.{
                .{ .name = "Accept", .value = "application/json" },
                .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
                .{ .name = "Authorization", .value = bearer },
            },
        });
        if (response.status != .ok) {
            std.log.err("http status {}: {s}", .{ response.status, &header_buf });
            return error.HttpStatusError;
        }
        return try std.json.parseFromSlice([]PullRequest, self._a, response_buf.items, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        });
    }
};

test "List Pull Requests" {
    const a = std.testing.allocator;
    var http_client = std.http.Client{ .allocator = a };
    defer http_client.deinit();
    var ghc = try GitHubClient.init(a, &http_client);
    defer ghc.deinit();
    const prs = try ghc.listPullRequests("MFAshby", "prtooltest1");
    defer prs.deinit();
    try std.json.stringify(prs.value, .{ .whitespace = .indent_2 }, std.io.getStdOut().writer());
}
