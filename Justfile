set shell := ["bash", "-c"]

# List available recipes
default:
    @just --list

# Build the project
build:
    go build ./...

# Run tests
test:
    go test ./...
    uv run pytest -q

# Run the project
run:
    go run ./...

# Format source code
fmt:
    gofmt -w .
    uv run ruff format .

# Lint / static analysis
lint:
    golangci-lint run
    uv run ruff check .

# Remove build artifacts
clean:
    go clean ./...
    rm -rf dist/ build/ __pycache__ .pytest_cache .venv .ruff_cache .mypy_cache
