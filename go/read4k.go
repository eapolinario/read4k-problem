package main

import (
    "bytes"
    "fmt"
    "io"
)

const DefaultChunkSize = 4096

type Reader4K struct {
	items []string
	i int
}

func (r4k *Reader4K) Read(buf []byte) (int, error) {
	if r4k.i >= len(r4k.items) {
    return 0, io.EOF
	}
	s := r4k.items[r4k.i]
	r4k.i++
	return copy(buf, s), nil
}

// ReadAllInChunks copies all data from r into a byte slice using a fixed-size
// buffer. It handles final partial reads and respects io.Reader semantics.
func ReadAllInChunks(r io.Reader, chunkSize int) ([]byte, error) {
    if chunkSize <= 0 {
        return nil, fmt.Errorf("chunk size must be greater than zero")
    }

    var out bytes.Buffer
    buf := make([]byte, chunkSize)

    for {
        n, err := r.Read(buf)
        if n > 0 {
            if _, writeErr := out.Write(buf[:n]); writeErr != nil {
                return nil, writeErr
            }
        }

        if err == io.EOF {
            return out.Bytes(), nil
        }
        if err != nil {
            return out.Bytes(), err
        }
    }
}

// CopyInChunks copies data from src to dst using a fixed-size buffer.
func CopyInChunks(dst io.Writer, src io.Reader, chunkSize int) (int64, error) {
    if chunkSize <= 0 {
        return 0, fmt.Errorf("chunk size must be greater than zero")
    }
    buf := make([]byte, chunkSize)
    return io.CopyBuffer(dst, src, buf)
}
