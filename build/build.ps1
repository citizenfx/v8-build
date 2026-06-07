# Define environment variables
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"

# Get the current directory of the script
$CURRENT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Current directory: $CURRENT_DIR"

# Define the directory to be mounted
$MOUNT_DIR = Split-Path -Path $CURRENT_DIR -Parent
$MOUNT_TARGET_DRIVE = "Y"
Write-Host "Mount directory: $MOUNT_DIR"

Invoke-Expression "subst ${MOUNT_TARGET_DRIVE}: /D" -ErrorAction SilentlyContinue
Invoke-Expression "subst ${MOUNT_TARGET_DRIVE}: $MOUNT_DIR" -ErrorAction SilentlyContinue

# Reading target commit/tag/branch hash
$REPOSITORY_TARGET_CHECKOUT = Get-Content "${MOUNT_TARGET_DRIVE}:\build\target.txt " -Raw 

# Fetch v8 source
& fetch v8
Set-Location "${MOUNT_TARGET_DRIVE}:\v8"
git reset --hard HEAD
git clean -fdx
# if "build" folder exists cd into it and clean it too
if (Test-Path -Path "${MOUNT_TARGET_DRIVE}:\v8\build") {
    Set-Location "${MOUNT_TARGET_DRIVE}:\v8\build"
    git reset --hard HEAD
    git clean -fdx
    Set-Location "${MOUNT_TARGET_DRIVE}:\v8"
}
# if "third_party/icu" folder exists cd into it and clean it too
if (Test-Path -Path "${MOUNT_TARGET_DRIVE}:\v8\third_party\icu") {
    Set-Location "${MOUNT_TARGET_DRIVE}:\v8\third_party\icu"
    git reset --hard HEAD
    git clean -fdx
    Set-Location "${MOUNT_TARGET_DRIVE}:\v8"
}
git checkout $REPOSITORY_TARGET_CHECKOUT
gclient sync -D
New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release"
New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.debug"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build\args_debug.gn" -Destination "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.debug\args.gn"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build\args_release.gn" -Destination "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release\args.gn"

####################################
#                                  #
#     Tricks and hacks zone        #
#                                  #
####################################

# Trick to force v8 to use static CRT
$filePath = "${MOUNT_TARGET_DRIVE}:\v8\build\config\BUILDCONFIG.gn"
$replaceWhat = '//build/config/win:default_crt'
$replaceWith = '//build/config/win:static_crt'
(Get-Content $filePath).Replace($replaceWhat, $replaceWith) | Set-Content $filePath

# Fixing bug with compiling inlined icudata in ASM with Clang
# This cheap trick breaks macos version compilation, but we don't care about that
$filePath = "${MOUNT_TARGET_DRIVE}:\v8\third_party\icu\scripts\make_data_assembly.py"
$replaceWhat = '_icudt%s_dat'
$replaceWith = 'icudt%s_dat'
(Get-Content $filePath).Replace($replaceWhat, $replaceWith) | Set-Content $filePath

# Add check for possible_transition_targets emptyness in js-heap-broker.cc as it's causing "empty range -> iterator deref" bug
$filePath = "${MOUNT_TARGET_DRIVE}:\v8\src\compiler\js-heap-broker.cc"
$replaceWhat = 'MapHandlesSpan(possible_transition_targets.begin(),'
$replaceWith = 'possible_transition_targets.empty() ? MapHandlesSpan() : MapHandlesSpan(possible_transition_targets.begin(),'
(Get-Content $filePath).Replace($replaceWhat, $replaceWith) | Set-Content $filePath

# Fix std::function -> base::FunctionRef incompatibility in backing-store.cc on newer V8/Clang builds
$filePath = "${MOUNT_TARGET_DRIVE}:\v8\src\objects\backing-store.cc"
$replaceWhat = 'auto gc_retry = [&](const std::function<bool()>& fn) {'
$replaceWith = 'auto gc_retry = [&](base::FunctionRef<bool()> fn) {'
(Get-Content $filePath).Replace($replaceWhat, $replaceWith) | Set-Content $filePath

# Increase Clang constexpr step limit for debug iterator builds
$filePath = "${MOUNT_TARGET_DRIVE}:\v8\BUILD.gn"
$replaceWhat = 'cflags += [ "-Wunreachable-code" ]'
$replaceWith = @'
cflags += [ "-Wunreachable-code" ]

    if (host_os == "win") {
      cflags += [ "/clang:-fconstexpr-steps=5242880" ]
    }
'@
(Get-Content $filePath -Raw).Replace($replaceWhat, $replaceWith) | Set-Content $filePath

####################################
#                                  #
#     Tricks and hacks zone end    #
#                                  #
####################################

gn gen out.gn/x64.debug
ninja -C out.gn/x64.debug -j16 v8_monolith

gn gen out.gn/x64.release
ninja -C out.gn/x64.release -j16 v8_monolith

New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\build_results"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.debug\obj\v8_monolith.lib" -Destination "${MOUNT_TARGET_DRIVE}:\build_results\v8_monolithd.lib"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release\obj\v8_monolith.lib" -Destination "${MOUNT_TARGET_DRIVE}:\build_results\v8_monolith.lib"

$PACKAGE_ROOT = "${MOUNT_TARGET_DRIVE}:\build_results\v8-package"
$PACKAGE_LIBS_DIR = "$PACKAGE_ROOT\libs"
$PACKAGE_INCLUDE_DIR = "$PACKAGE_ROOT\include\v8"
$PACKAGE_ARCHIVE = "${MOUNT_TARGET_DRIVE}:\build_results\v8.tar.xz"

Remove-Item -Path $PACKAGE_ROOT -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $PACKAGE_ARCHIVE -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $PACKAGE_LIBS_DIR
New-Item -ItemType Directory -Force -Path $PACKAGE_INCLUDE_DIR
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build_results\v8_monolithd.lib" -Destination $PACKAGE_LIBS_DIR
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build_results\v8_monolith.lib" -Destination $PACKAGE_LIBS_DIR
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\v8\include\*" -Destination $PACKAGE_INCLUDE_DIR -Recurse -Force
tar.exe -cJf $PACKAGE_ARCHIVE -C $PACKAGE_ROOT .
Remove-Item -Path $PACKAGE_ROOT -Recurse -Force

# Attempt to clean up and remove X: mapping at the end; ignore errors
Invoke-Expression "subst ${MOUNT_TARGET_DRIVE}: /D" -ErrorAction SilentlyContinue
