load("@bazel_skylib//lib:paths.bzl", "paths")
load("@aspect_rules_js//js:defs.bzl", "js_run_binary", "js_run_devserver")

def undo_chdir(*, chdir, path):
    """
    Generate a relative path which undoes a `chdir` path.
    """
    return paths.join("/".join([".." for _ in chdir.split("/")]), path) if chdir else path

def vite_build(*, name, vite_config, srcs, outs = [], out_dirs = ["dist"], tool = "//tools:vite", **kwargs):
    """
    Macro for building a Vite bundle.

    Args:
        name: A unique name for this target.

        vite_config: Label of a `js_library()` target that represents the Vite config.

        srcs: A list of source files.

        outs: A list of output files.

        out_dirs: (Optional) A list of output directories.

        tool: Label of the Vite binary.

        **kwargs: Additional arguments
    """

    chdir = native.package_name()
    js_run_binary(
        name = name,
        srcs = srcs + [vite_config],
        args = [
            "build",
            "--config",
            undo_chdir(chdir = chdir, path = "$(rootpath {vite_config})".format(vite_config = vite_config)),
        ],
        chdir = chdir,
        outs = outs,
        out_dirs = out_dirs,
        tool = tool,
        **kwargs
    )