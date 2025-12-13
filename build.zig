const std = @import("std");

pub fn assemblyFiles(b: *std.Build, link_to: *std.Build.Step.Compile, files: []const std.Build.LazyPath) *std.Build.Step {
    const step = b.step("asm", "Build assembly files");
    for (files) |file| {
        const syscmd = b.addSystemCommand(&.{"nasm"});
        syscmd.addArgs(&.{ "-f", "elf64" });
        syscmd.addFileArg(file);
        syscmd.addArg("-o");
        const file_basename = std.fs.path.stem(file.getPath(b));
        const output_object = syscmd.addOutputFileArg(b.fmt("{s}.o", .{file_basename}));
        step.dependOn(&syscmd.step);
        link_to.addObjectFile(output_object);
    }

    link_to.step.dependOn(step);
    return step;
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

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .red_zone = false,
            .code_model = .kernel,
            //            .omit_frame_pointer = true,
            //            .stack_check = false,
            //            .stack_protector = false,
            //            .pic = false,
        }),
        .linkage = .static,
    });
    const asm_step = assemblyFiles(b, exe, &.{
        b.path("asm-src/entry.asm"),
        b.path("asm-src/interrupts.asm"),
    });

    exe.root_module.addCSourceFile(.{ .file = b.path("c-src/port.c") });
    exe.root_module.addCSourceFile(.{ .file = b.path("c-src/interrupts.c") });

    exe.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(exe);

    _ = asm_step;
}
