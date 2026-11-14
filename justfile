# MoonBit Project Commands

# Default target (js for browser compatibility)
target := "js"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --deny-warn --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Run main
run *args:
    moon run src/main --target {{target}} -- {{args}}

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test

# Compare type semantics and function JSON with wasm-tools (requires Python 3)
spec-check *args:
    python3 scripts/check-spec.py {{args}}

# Build the pinned upstream WIT oracle (requires Cargo and network access)
spec-reference:
    python3 scripts/build-spec-reference.py
