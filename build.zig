const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const osslsigncode_origin_dep = b.dependency("osslsigncode-origin", .{ .target = target, .optimize = optimize });
    const openssl_dep = b.dependency("openssl", .{ .target = target, .optimize = optimize });
    const zlib_dep = b.dependency("zlib", .{ .target = target, .optimize = optimize });

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib_mod.linkLibrary(openssl_dep.artifact("openssl"));
    lib_mod.linkLibrary(zlib_dep.artifact("z"));

    // FIXME: why don't these work from config.h?
    lib_mod.addCMacro("HAVE_SYS_MMAN_H", "");
    lib_mod.addCMacro("HAVE_MMAP", "");

    // TODO: https://github.com/vezel-dev/graf/issues/15
    const zon_bytes = b.build_root.handle.readFileAllocOptions(
        b.allocator,
        "build.zig.zon",
        4096,
        null,
        1,
        0,
    ) catch unreachable;

    var status: std.zon.parse.Status = .{};
    defer status.deinit(b.allocator);

    const zon_data = std.zon.parse.fromSlice(
        struct { version: []const u8 },
        b.allocator,
        zon_bytes,
        &status,
        .{
            .ignore_unknown_fields = true,
        },
    ) catch |e| {
        std.debug.print("error {} and bad zon status:\n{}\n", .{ e, status });
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        return;
    };

    const VersionInfo = struct {
        major_str: []const u8,
        minor_str: []const u8,
    };

    const version: VersionInfo = _: {
        const dot_idx = std.mem.indexOf(u8, zon_data.version, ".") orelse std.debug.panic(
            "Version '{s}' contained no '.'",
            .{zon_data.version},
        );
        break :_ .{
            .major_str = zon_data.version[0..dot_idx],
            .minor_str = zon_data.version[dot_idx + 1 ..],
        };
    };

    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = osslsigncode_origin_dep.path("Config.h.in") },
        .include_path = "config.h",
    }, .{
        // the configured options and settings for osslsigncode
        .osslsigncode_VERSION_MAJOR = version.major_str,
        .osslsigncode_VERSION_MINOR = version.minor_str,
        // SEE: https://github.com/mtrojnar/osslsigncode/blob/4568c890cc1538ca80be3ee36775ba42223dea04/CMakeLists.txt#L23
        .PACKAGE_STRING = std.fmt.allocPrint(b.allocator, "osslsigncode {s}", .{zon_data.version}) catch unreachable,
        .PACKAGE_BUGREPORT = "Michal.Trojnara@stunnel.org",
        // FIXME: these don't work, see above hack
        .HAVE_SYS_MMAN_H = "",
        .HAVE_MMAP = "",
    });

    lib_mod.addConfigHeader(config_h);
    lib_mod.addIncludePath(osslsigncode_origin_dep.path("."));
    lib_mod.addCSourceFiles(.{
        .root = osslsigncode_origin_dep.path("."),
        .files = &.{
            // TODO: if not unix according to Makefile
            //"applink.c",
            "appx.c",
            "cab.c",
            "cat.c",
            "helpers.c",
            "msi.c",
            "osslsigncode.c",
            "pe.c",
            "script.c",
            "utf.c",
        },
        .flags = &.{},
    });

    const exe = b.addExecutable(.{
        .name = "osslsigncode",
        .root_module = lib_mod,
    });

    b.installArtifact(exe);
}
