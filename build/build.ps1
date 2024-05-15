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

# Reading target commit hash
$COMMIT = Get-Content "${MOUNT_TARGET_DRIVE}:\build\target_commit.txt " -Raw 

# Fetch v8 source
& fetch v8
New-Item -ItemType Directory -Force -Path "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release"
Copy-Item -Path "${MOUNT_TARGET_DRIVE}:\build\args_debug.gn" -Destination "${MOUNT_TARGET_DRIVE}:\v8\out.gn\x64.release\"
Set-Location "${MOUNT_TARGET_DRIVE}:\v8"
git checkout $COMMIT
gclient sync
gn gen out.gn/x64.release
ninja -C out.gn/x64.release -j16 v8

# Attempt to clean up and remove X: mapping at the end; ignore errors
Invoke-Expression "subst ${MOUNT_TARGET_DRIVE}: /D" -ErrorAction SilentlyContinue