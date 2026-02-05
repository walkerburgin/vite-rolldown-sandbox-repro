# `vite-rolldown-sandbox-repro`

## Repro

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

In `vite`:
- `config.root`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/79/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app`
- `normalizedId`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/79/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html
- `shortEmitName`: `index.html`

In `rolldown-vite`:
- `config.root`:  `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/sandbox/darwin-sandbox/21/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app`
- `normalizedId`: `/private/var/tmp/_bazel_walkerburgin/e137f21f17bb052f4413ecef2c4599eb/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html`
  * **NOTE** that this path is outside of `sandbox/darwin-sandbox`
- shortEmitName: `../../../../../../../../../../../execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/packages/foo-app/index.html`
