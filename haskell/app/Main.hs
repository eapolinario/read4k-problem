module Main (main) where

import Read4K (copyInChunks, defaultChunkSize)
import System.IO (hSetBinaryMode, stdin, stdout)

-- A binary-safe filter: copy stdin to stdout using 4096-byte reads.
main :: IO ()
main = do
    hSetBinaryMode stdin True
    hSetBinaryMode stdout True
    _ <- copyInChunks stdout stdin defaultChunkSize
    pure ()
