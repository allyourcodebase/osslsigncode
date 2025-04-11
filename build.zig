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

    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = osslsigncode_origin_dep.path("Config.h.in") },
        .include_path = "config.h",
    }, .{
        // the configured options and settings for osslsigncode
        // TODO: keep in sync with build.zig.zon
        .osslsigncode_VERSION_MAJOR = "2",
        .osslsigncode_VERSION_MINOR = "9",
        // SEE: https://github.com/mtrojnar/osslsigncode/blob/4568c890cc1538ca80be3ee36775ba42223dea04/CMakeLists.txt#L23
        .PACKAGE_STRING = "osslsigncode 2.9",
        .PACKAGE_BUGREPORT = "Michal.Trojnara@stunnel.org",
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
