package main

import (
    "io"
    "testing"
)

func TestReadAllInChunks(t *testing.T) {
	r4k := &Reader4K{
		items: []string{"a", "b", "c"},
	}
	got, err := ReadAllInChunks(r4k, 2)
	if err != nil {
		t.Fatalf("ReadAllInChunks returned error: %v", err)
	}

	expected := "abc"
	if string(got) != expected {
		t.Fatalf("ReadAllInChunks mismatch: got %q want %q", got, expected)
	}
}

func TestReader4KLimitedReader(t *testing.T) {
	r4k := &Reader4K{
		items: []string{"hello", " world"},
	}

	limited := &io.LimitedReader{R: r4k, N: 5}
	buf := make([]byte, 5)
	n, err := limited.Read(buf)
	if err != nil {
		t.Fatalf("limited Read returned error: %v", err)
	}
	if n != 5 {
		t.Fatalf("limited Read returned %d bytes, want 5", n)
	}
	if got, want := string(buf[:n]), "hello"; got != want {
		t.Fatalf("limited Read mismatch: got %q want %q", got, want)
	}
}
