const std = @import("std");

pub fn assemblyFiles(b: *std.Build, link_to: *std.Build.Module, step: *std.Build.Step, files: []const std.Build.LazyPath) void {
    for (files) |file| {
        const syscmd = b.addSystemCommand(&.{"nasm"});
        syscmd.addArgs(&.{ "-f", "elf64" });
        syscmd.addFileArg(file);
        syscmd.addArg("-o");
        const file_basename = std.fs.path.stem(file.getPath(b));
        const output_object = syscmd.addOutputFileArg(b.fmt("{s}.o", .{file_basename}));
        link_to.addObjectFile(output_object);
        step.dependOn(&syscmd.step);
    }
}

pub fn build(b: *std.Build) void {
    const Target = std.Target.x86;
    const target = b.resolveTargetQuery(.{
        .abi = .none,
        .cpu_arch = .x86_64,
        .cpu_features_add = Target.featureSet(&.{ .soft_float, .popcnt }),
        .cpu_features_sub = Target.featureSet(&.{ .sse, .sse2, .avx, .avx2, .mmx }),
        .os_tag = .freestanding,
        .ofmt = .elf,
    });

    const core = b.addModule("core", .{
        .code_model = .kernel,
        .red_zone = false,
        .optimize = .ReleaseFast,
        .target = target,
        .root_source_file = b.path("kernel/src/core/core.zig"),
    });
    core.addCSourceFile(.{ .file = b.path("kernel/src/core/cpu/port.c") });
    core.addCSourceFile(.{ .file = b.path("kernel/src/core/cpu/interrupts.c") });

    const klib = b.addModule("klib", .{
        .code_model = .kernel,
        .red_zone = false,
        .optimize = .ReleaseFast,
        .target = target,
        .root_source_file = b.path("kernel/src/klib/klib.zig"),
        .imports = &.{
            .{ .name = "core", .module = core },
        },
    });

    const drivers = b.addModule("drivers", .{
        .code_model = .kernel,
        .red_zone = false,
        .optimize = .ReleaseFast,
        .target = target,
        .root_source_file = b.path("kernel/src/drivers/drivers.zig"),
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "klib", .module = klib },
        },
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .linkage = .static,
        .root_module = b.createModule(.{
            .code_model = .kernel,
            .red_zone = false,
            .optimize = .ReleaseFast,
            .target = target,
            .root_source_file = b.path("kernel/src/main.zig"),
            .imports = &.{
                .{ .name = "core", .module = core },
                .{ .name = "klib", .module = klib },
                .{ .name = "drivers", .module = drivers },
            },
        }),
    });

    assemblyFiles(b, kernel.root_module, &kernel.step, &.{
        b.path("kernel/src/boot/entry.asm"),
        b.path("kernel/src/boot/header.asm"),
    });

    assemblyFiles(b, core, &kernel.step, &.{
        b.path("kernel/src/core/cpu/interrupts.asm"),
    });

    kernel.setLinkerScript(b.path("kernel/linker.ld"));

    // const exe = b.addExecutable(.{
    //     .name = "kernel.elf",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = .ReleaseFast,
    //         .red_zone = false,
    //         .code_model = .kernel,
    //         //            .omit_frame_pointer = true,
    //         //            .stack_check = false,
    //         //            .stack_protector = false,
    //         //            .pic = false,
    //     }),
    //     .linkage = .static,
    // });

    // const asm_step = assemblyFiles(b, exe, &.{
    //     b.path("asm-src/entry.asm"),
    //     b.path("asm-src/interrupts.asm"),
    // });

    // exe.root_module.addCSourceFile(.{ .file = b.path("c-src/port.c") });
    // exe.root_module.addCSourceFile(.{ .file = b.path("c-src/interrupts.c") });

    // exe.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(kernel);

    // _ = asm_step;
}
