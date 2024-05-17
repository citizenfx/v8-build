# V8 Build Tools

This repository contains all the necessary tools and scripts to build Google's V8 for embedding.

## Prerequisites

1. **Clone this repository:**

    ```sh
    git clone https://github.com/citizenfx/v8-build.git
    cd v8-build
    ```

2. **Python 3.8+ must be installed on your system.**

3. **Drive Mapping:**

    Ensure you do not have a drive mapped to the letter 'Y'. If you do, change the mapping drive target to another letter in the `prepare-depot.ps1` and `build.ps1` files.

## Building V8

1. **Prepare the depot:**

    Run the following script to prepare the depot:

    ```sh
    .\build\prepare-depot.ps1
    ```

2. **Build V8:**

    Run the build script:

    ```sh
    .\build\build.ps1
    ```

3. **Wait approximately 20 minutes** for the build process to complete.

## Build Results

The build results will be located in the `build_results` folder.
