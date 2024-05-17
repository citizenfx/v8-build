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
New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release"
New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.debug"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build\args_debug.gn" -Destination "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.debug\args.gn"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build\args_release.gn" -Destination "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release\args.gn"
Set-Location "${MOUNT_TARGET_DRIVE}:\v8"
git checkout $REPOSITORY_TARGET_CHECKOUT
gclient sync

####################################
#                                  #
#     Tricks and hacks zone        #
#                                  #
####################################

# Trick to force v8 to use dynamic CRT
(Get-Content "${MOUNT_TARGET_DRIVE}:\v8\build\config\BUILDCONFIG.gn").Replace('//build/config/win:default_crt', '//build/config/win:dynamic_crt') | Set-Content "${MOUNT_TARGET_DRIVE}:\v8\build\config\BUILDCONFIG.gn"

# Fixing bug with compiling inlined icudata in ASM with Clang
# This cheap trick breaks macos version compilation, but we don't care about that
(Get-Content "${MOUNT_TARGET_DRIVE}:\v8\third_party\icu\scripts\make_data_assembly.py").Replace('_icudt%s_dat', 'icudt%s_dat') | Set-Content "${MOUNT_TARGET_DRIVE}:\v8\third_party\icu\scripts\make_data_assembly.py"

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

# Attempt to clean up and remove X: mapping at the end; ignore errors
Invoke-Expression "subst ${MOUNT_TARGET_DRIVE}: /D" -ErrorAction SilentlyContinue
