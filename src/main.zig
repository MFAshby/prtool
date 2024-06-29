const std = @import("std");
const GitHubClient = @import("root.zig").GitHubClient;
const sqlite = @import("sqlite");

pub fn main() !void {
    // Talk to github - std.http
    // Present a UI - vaxis
    // Store local stuff in a structured fashion - sqlite
    // interact with a git repository - https://github.com/libgit2/libgit2/archive/refs/tags/v1.8.2-rc1.tar.gz
    // although at the moment we just need to read the remotes, we can probably do that ourselves.

    // but the main question, how does this all fit together :D

    //
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const db = try sqlite.Db.init(.{});
    _ = db;

    var http_client = std.http.Client{ .allocator = a };
    defer http_client.deinit();
    var ghc = try GitHubClient.init(a, &http_client);
    defer ghc.deinit();
    const prs = try ghc.listPullRequests("MFAshby", "prtooltest1");
    defer prs.deinit();
    try std.json.stringify(prs.value, .{ .whitespace = .indent_2 }, std.io.getStdOut().writer());
}
