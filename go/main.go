package main

import (
	"fmt"
)

func main() {
	r4k := &Reader4K{
		items: []string{"hello", "world"},
	}

	data, err := ReadAllInChunks(r4k, 5)
	if err != nil {
		panic(err)
	}

	fmt.Printf("read %d bytes\n", len(data))
	fmt.Printf("data = %s", string(data))
}
