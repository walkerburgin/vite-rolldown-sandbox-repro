# `vite-rolldown-sandbox-repro`

## Repro (02/04/2026)

Run `bazel build //packages/foo-app:vite`

```
➜  vite-rolldown-sandbox-repro (develop) bazel build //packages/foo-app:vite
INFO: Analyzed target //packages/foo-app:vite (0 packages loaded, 7893 targets configured).
INFO: Found 1 target...
INFO: From JsRunBinary packages/foo-app/dist:
rolldown-vite v7.3.1 building client environment for production...
transforming...✓ 3 modules transformed.
rendering chunks...
computing gzip size...
dist/../../../../../../../../../../execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html  0.14 kB │ gzip: 0.12 kB
dist/assets/index-YiMfhTXK.js                                                                                       0.72 kB │ gzip: 0.41 kB
✓ built in 19ms
Target //packages/foo-app:vite up-to-date:
  bazel-bin/packages/foo-app/dist
INFO: Elapsed time: 2.860s, Critical Path: 2.46s
INFO: 224 processes: 3 action cache hit, 121 internal, 98 darwin-sandbox, 5 local.
INFO: Build completed successfully, 224 total actions
FATAL: bazel crashed due to an internal error. Printing stack trace:
java.lang.IllegalStateException: Found unexpected entries in sandbox base. Please report this in https://github.com/bazelbuild/bazel/issues. The entries are: _moved_trash_dir, execroot, sandbox_stash
        at com.google.devtools.build.lib.sandbox.SandboxModule.checkSandboxBaseTopOnlyContainsPersistentDirs(SandboxModule.java:573)
        at com.google.devtools.build.lib.sandbox.SandboxModule.afterCommand(SandboxModule.java:611)
        at com.google.devtools.build.lib.runtime.BlazeRuntime.afterCommand(BlazeRuntime.java:734)
        at com.google.devtools.build.lib.runtime.BlazeCommandDispatcher.execExclusively(BlazeCommandDispatcher.java:711)
        at com.google.devtools.build.lib.runtime.BlazeCommandDispatcher.exec(BlazeCommandDispatcher.java:257)
        at com.google.devtools.build.lib.server.GrpcServerImpl.executeCommand(GrpcServerImpl.java:607)
        at com.google.devtools.build.lib.server.GrpcServerImpl.lambda$run$0(GrpcServerImpl.java:677)
        at io.grpc.Context$1.run(Context.java:566)
        at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.base/java.lang.Thread.run(Unknown Source)
```

**Note the output path for `index.html`.**

If we disable the Bazel sandbox by adding the `no-sandbox` tag to the `vite` target:

```diff
--- a/packages/foo-app/BUILD
+++ b/packages/foo-app/BUILD
@@ -38,4 +38,5 @@ vite_build(
     ],
     vite_config = ":vite_config",
     silent_on_success = False,
+    tags = ["no-sandbox"],
 )
```

We get output that looks more like what we'd expect (and Bazel doesn't crash):

```
➜  vite-rolldown-sandbox-repro (develop) bazel build //packages/foo-app:vite
Starting local Bazel server (8.5.1) and connecting to it...
INFO: Analyzed target //packages/foo-app:vite (179 packages loaded, 7939 targets configured).
INFO: Found 1 target...
INFO: From JsRunBinary packages/foo-app/dist:
rolldown-vite v7.3.1 building client environment for production...
transforming...✓ 3 modules transformed.
rendering chunks...
computing gzip size...
dist/index.html                0.14 kB │ gzip: 0.12 kB
dist/assets/index-YiMfhTXK.js  0.72 kB │ gzip: 0.41 kB
✓ built in 16ms
Target //packages/foo-app:vite up-to-date:
  bazel-bin/packages/foo-app/dist
INFO: Elapsed time: 3.802s, Critical Path: 0.26s
INFO: 2 processes: 225 action cache hit, 1 internal, 1 local.
INFO: Build completed successfully, 2 total actions
```

After comparing `rolldown-vite` with `vite`, I believe that the module ids in `rolldown-vite` are escaping
the Bazel sandbox. I added some logging to the `vite:build-html` plugin and here's what I saw.

**In `vite`:**
- `config.root`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/79/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app`
- `normalizedId`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/79/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html`
- `shortEmitName`: `index.html`

**In `rolldown-vite`:**
- `config.root`:  `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/21/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app`
- `normalizedId`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html`
- `shortEmitName`: `../../../../../../../../../../../execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html`

Note that the `normalizedId` path is outside of the sandbox.

Here are what the symlinks in the sandbox look like:

```
/private/var/tmp/_bazel_walkerburgin/32bf7be53319b4e2feed5a0cebe8773b/sandbox/darwin-sandbox/1/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app
├── app.mjs -> /private/var/tmp/_bazel_walkerburgin/32bf7be53319b4e2feed5a0cebe8773b/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/app.mjs
├── app.mjs.map -> /private/var/tmp/_bazel_walkerburgin/32bf7be53319b4e2feed5a0cebe8773b/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/app.mjs.map
├── index.html -> /private/var/tmp/_bazel_walkerburgin/32bf7be53319b4e2feed5a0cebe8773b/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html
└── vite.config.mjs -> /private/var/tmp/_bazel_walkerburgin/32bf7be53319b4e2feed5a0cebe8773b/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/vite.config.mjs
```

## Update (03/12/2026)

After bumping to `vite@8.0.0`, running `bazel build //packages/foo-app:vite` produces this error:

```bash
➜  vite-rolldown-sandbox-repro git:(develop) ✗ bazel build //packages/foo-app:vite
INFO: Analyzed target //packages/foo-app:vite (2 packages loaded, 167 targets configured).
INFO: Found 1 target...
ERROR: /Users/wburgin/Repositories/walkerburgin/vite-rolldown-sandbox-repro/packages/foo-app/BUILD:33:11: JsRunBinary packages/foo-app/dist failed: (Exit 1): vite failed: error executing JsRunBinary command (from target //packages/foo-app:vite) bazel-out/darwin_arm64-opt-exec-ST-d57f47055a04/bin/tools/vite_/vite build --config ../../packages/foo-app/vite.config.mjs

Use --sandbox_debug to see verbose messages from the sandbox and retain the sandbox build root for debugging
✗ Build failed in 18ms
error during build:
Build failed with 1 error:

[plugin vite:build-html]
Error: The "fileName" or "name" properties of emitted chunks and assets must be strings that are neither absolute nor relative paths, received "../../../../../../../../../../execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html".
    at PluginContextImpl.emitFile (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/bindingify-input-options-Cu7pt6SZ.mjs:903:23)
    at PluginContextImpl.generateBundle (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/vite@8.0.0_at_types_node_25.5.0/node_modules/vite/dist/node/chunks/node.js:22411:10)
    at async plugin (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/bindingify-input-options-Cu7pt6SZ.mjs:1294:4)
    at async plugin.<computed> (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/bindingify-input-options-Cu7pt6SZ.mjs:1570:12)
    at aggregateBindingErrorsIntoJsError (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/error-CP8smW_P.mjs:48:18)
    at unwrapBindingResult (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/error-CP8smW_P.mjs:18:128)
    at #build (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/rolldown@1.0.0-rc.9/node_modules/rolldown/dist/shared/rolldown-build-4YnQkA76.mjs:3311:34)
    at async buildEnvironment (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/vite@8.0.0_at_types_node_25.5.0/node_modules/vite/dist/node/chunks/node.js:32794:64)
    at async Object.build (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/vite@8.0.0_at_types_node_25.5.0/node_modules/vite/dist/node/chunks/node.js:33216:19)
    at async Object.buildApp (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/vite@8.0.0_at_types_node_25.5.0/node_modules/vite/dist/node/chunks/node.js:33213:153)
    at async CAC.<anonymous> (file:///private/var/tmp/_bazel_wburgin/a445ef3cc4d16c0c48261b5007ab73bb/sandbox/darwin-sandbox/2339/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/node_modules/.aspect_rules_js/vite@8.0.0_at_types_node_25.5.0/node_modules/vite/dist/node/cli.js:778:3) {
  errors: [Getter/Setter]
}
vite v8.0.0 building client environment for production...
transforming...✓ 4 modules transformed.
rendering chunks...
Target //packages/foo-app:vite failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 3.878s, Critical Path: 3.12s
INFO: 230 processes: 124 internal, 101 darwin-sandbox, 5 local.
ERROR: Build did NOT complete successfully
```
