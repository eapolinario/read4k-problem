{-# LANGUAGE BangPatterns #-}

module Read4K (
    defaultChunkSize,
    foldChunks,
    readAllInChunks,
    copyInChunks,
) where

import qualified Data.ByteString as BS
import System.IO (Handle)

-- | The maximum number of bytes requested by a read4k operation.
defaultChunkSize :: Int
defaultChunkSize = 4096

{- | Fold over a blocking chunk reader. The reader must return at most the
requested number of bytes, with an empty chunk indicating EOF. A nonempty
short read is not EOF: process it, then read again.

The accumulator is kept strict, and nonpositive chunk sizes are rejected
before calling either the reader or the folding step. I/O errors propagate.
-}
foldChunks :: Int -> (Int -> IO BS.ByteString) -> (a -> BS.ByteString -> IO a) -> a -> IO a
foldChunks chunkSize readChunk step initial
    | chunkSize <= 0 = ioError (userError "chunk size must be greater than zero")
    | otherwise = go initial
  where
    go !acc = do
        chunk <- readChunk chunkSize
        if BS.null chunk
            then pure acc
            else step acc chunk >>= go

{- | Read all remaining bytes from a handle. Chunks are collected in reverse
order and concatenated once, avoiding quadratic repeated append operations.
This uses O(n) memory for n bytes of input; the caller owns the handle.
-}
readAllInChunks :: Handle -> Int -> IO BS.ByteString
readAllInChunks source chunkSize =
    BS.concat . reverse
        <$> foldChunks chunkSize (BS.hGetSome source) (\chunks chunk -> pure (chunk : chunks)) []

{- | Copy all remaining bytes and return the number of bytes copied.
This uses O(chunkSize) working memory. It does not close either handle or
explicitly flush the destination. Read and write errors propagate to the caller.
-}
copyInChunks :: Handle -> Handle -> Int -> IO Integer
copyInChunks destination source chunkSize =
    foldChunks chunkSize (BS.hGetSome source) writeChunk 0
  where
    writeChunk total chunk = do
        BS.hPut destination chunk
        pure (total + fromIntegral (BS.length chunk))
