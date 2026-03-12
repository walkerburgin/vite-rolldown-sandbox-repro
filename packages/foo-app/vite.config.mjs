import { defineConfig } from "vite";
import fs from "node:fs";
import util from "node:util";

const realpath = util.promisify(fs.realpath.native);

export default defineConfig({
    root: await realpath(import.meta.dirname),
});
