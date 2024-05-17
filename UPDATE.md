# In case if update needed
## Things you need to know
* There was bug in ICU script that generating ASM file with icudata for embedding. If it still generates ASM file with `icudata` variable that prefixed with `_` - bug still exists and clang compilation will fail. We are doing trick to remove underscore in build script
* By default v8_monolith use static crt, so are forcing it to use dynamic CRT. Maybe with some time Google will fix it, so then you need to check flags with `gn args` and look for flag that forcing dynamic crt to be used.

## How to update to newer V8
Simply put new commit hash/tag/branch from [V8 repository](https://github.com/v8/v8) into `target.txt`. It will be added to `git checkout` command