# read4k-problem

A small repository for exploring the classic read4k interview problem in Go and Python 3.14, with a Nix-based development environment.

## Goal

Implement a robust solution that reads from a stream in 4096-byte chunks and correctly handles the final partial chunk without losing data.

## Why this problem?

This pattern exercises:

- chunked I/O
- buffering and stream processing
- handling EOF and partial reads
- idiomatic patterns in multiple languages

## Repository layout

```text
.
├── README.md
├── flake.nix
├── Justfile
├── .envrc
├── .gitignore
├── go/
│   └── ...
├── python/
│   └── ...
└── docs/
    └── ...
```

## Development environment

This repo uses a Nix flake with both Go and Python tooling enabled.

```bash
cd /home/eduardo/repos/read4k-problem
nix develop
# or
# direnv allow
```

Then use the provided Just recipes:

```bash
just build
just test
just run
just fmt
just lint
```

## Getting started

### Go

```bash
cd go
go run .
```

### Python

```bash
cd python
uv sync
uv run python main.py
```

## Notes

This repo is meant to stay lightweight while we work through the problem in a few languages, starting with Go and Python.
