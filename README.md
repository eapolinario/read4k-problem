# read4k-problem

A small repository for exploring the classic read4k interview problem in Go, Python 3.14, and Haskell, with a Nix-based development environment.

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
├── .envrc
├── .gitignore
├── go/
│   ├── Justfile
│   └── ...
├── python/
│   ├── Justfile
│   └── ...
└── haskell/
    ├── Justfile
    ├── cabal.project
    ├── read4k.cabal
    ├── src/Read4K.hs
    ├── app/Main.hs
    └── test/Main.hs
```

## Development environment

This repo uses a Nix flake with Go, Python, and Haskell tooling enabled, including GHC, Cabal, Haskell Language Server, Fourmolu, HLint, and Just.

```bash
cd /home/eduardo/repos/read4k-problem
nix develop
# or
# direnv allow
```

Then use the language-local Just recipes:

```bash
cd go
just build
just test
just run
just fmt
just lint

cd ../python
just setup
just test
just run
just fmt
just lint

cd ../haskell
just build
just test
just fmt
just lint
printf 'hello from Haskell\n' | just run
```

## Getting started

### Go

```bash
cd go
just run
```

### Python

```bash
cd python
just setup
just run
```

### Haskell

```bash
cd haskell
just test
printf 'hello from Haskell\n' | just run
# Or copy a binary file:
just run < input.bin > output.bin
```

The library uses strict `ByteString`s and `hGetSome` to request at most 4096 bytes per read by default. **Only an empty read means EOF**; a nonempty short read is processed before reading again.

- `readAllInChunks source chunkSize` collects the remaining input and concatenates the chunks once, using O(n) memory.
- `copyInChunks destination source chunkSize` streams the input with O(chunkSize) working memory and returns an `Integer` byte count.
- `foldChunks` exposes the same loop for custom readers and consumers, with a strict accumulator.

Nonpositive chunk sizes are rejected before I/O. Exceptions propagate, and callers retain ownership of their handles. Tests cover chunk boundaries, final and intermediate short reads, binary data, custom chunk sizes, EOF, and I/O failures. The package uses only libraries bundled with GHC, so no `cabal update` is needed.

## Notes

This repo is meant to stay lightweight while we work through the problem in a few languages.
