load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_ts//ts:defs.bzl", "ts_config", "ts_project")
load("@npm//:defs.bzl", "npm_link_all_packages")
load("//bazel:defs.bzl", "vite_build")

# gazelle:js_files vite_config vite.config.mjs

npm_link_all_packages(name = "node_modules")

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    visibility = [":__subpackages__"],
)

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

js_library(
    name = "vite_config",
    srcs = ["vite.config.mjs"],
    deps = ["//:node_modules/vite"],
)

vite_build(
    name = "vite",
    srcs = [
        "index.html",
        ":foo-app",
    ],
    silent_on_success = False,
    vite_config = ":vite_config",
)
