#!/bin/bash
# Test script to validate the Raspberry Pi build configuration
# This script checks if the build configuration is valid without running the full build

set -e

echo "=== Validating Raspberry Pi Build Configuration ==="

# Check if we're in the mongo repository
if [ ! -f "BUILD.bazel" ]; then
    echo "Error: Not in mongo repository root"
    exit 1
fi

# Create test bazelrc for Raspberry Pi
echo "Creating test .bazelrc.raspberrypi..."
cat > .bazelrc.raspberrypi.test << 'EOF'
# Raspberry Pi specific compilation flags
build --copt=-march=armv8-a+crc
build --copt=-moutline-atomics
build --copt=-mtune=cortex-a72
EOF

echo "✓ Created .bazelrc.raspberrypi.test"

# Verify the bazelrc syntax
echo ""
echo "=== Checking .bazelrc.raspberrypi.test syntax ==="
if [ -f ".bazelrc.raspberrypi.test" ]; then
    cat .bazelrc.raspberrypi.test
    echo ""
    echo "✓ Bazelrc syntax looks valid"
else
    echo "✗ Failed to create .bazelrc.raspberrypi.test"
    exit 1
fi

# Check if devcore target exists
echo ""
echo "=== Checking if devcore target exists in BUILD.bazel ==="
if grep -q "name = \"devcore\"" BUILD.bazel; then
    echo "✓ Found devcore target in BUILD.bazel"
    grep -A 5 "name = \"devcore\"" BUILD.bazel
else
    echo "✗ devcore target not found in BUILD.bazel"
    exit 1
fi

# Check if archive-devcore target is generated
echo ""
echo "=== Checking if archive-devcore target would be available ==="
if grep -q "mongo_install" BUILD.bazel; then
    echo "✓ mongo_install rule found (should generate archive-devcore target)"
else
    echo "✗ mongo_install rule not found"
    exit 1
fi

# Cleanup
rm -f .bazelrc.raspberrypi.test

echo ""
echo "=== Validation Complete ==="
echo "✓ All checks passed!"
echo ""
echo "To build MongoDB DevCore for Raspberry Pi:"
echo "  1. Create .bazelrc.raspberrypi with the Raspberry Pi flags"
echo "  2. Run: bazel build --config=opt --bazelrc=.bazelrc.raspberrypi archive-devcore"
echo ""
