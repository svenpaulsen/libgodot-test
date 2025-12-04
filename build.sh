#!/bin/bash

set -e

BUILD_DIR="build"
BUILD_TYPE="${1:-Debug}"

# Create build directory if it doesn't exist
mkdir -p "$BUILD_DIR"

# Configure with CMake
cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

# Build
cmake --build "$BUILD_DIR" --parallel
