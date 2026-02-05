load("@aspect_rules_ts//ts:defs.bzl", "ts_config", "ts_project")
load("@npm//:defs.bzl", "npm_link_all_packages")

npm_link_all_packages(name = "node_modules")

ts_project(
    name = "foo-app",
    srcs = ["app.mts"],
    declaration = True,
    declaration_map = True,
    isolated_typecheck = True,
    preserve_jsx = False,
    source_map = True,
    tsconfig = ":tsconfig",
)

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    visibility = [":__subpackages__"],
)
