{-# LANGUAGE LambdaCase #-}

module Main (main) where

import Control.Exception (IOException, SomeException, bracket, displayException, finally, try)
import Control.Monad (forM, forM_, unless, void)
import qualified Data.ByteString as BS
import Data.IORef (atomicModifyIORef', modifyIORef', newIORef, readIORef)
import Read4K (copyInChunks, defaultChunkSize, foldChunks, readAllInChunks)
import System.Directory (getTemporaryDirectory, removeFile)
import System.Exit (exitFailure)
import System.IO (Handle, SeekMode (AbsoluteSeek), hClose, hIsOpen, hSeek, hTell, openBinaryTempFile)
import System.IO.Error (ioeGetErrorString)

main :: IO ()
main = do
    results <- forM tests $ \(name, action) -> do
        result <- try action :: IO (Either SomeException ())
        case result of
            Left err -> do
                putStrLn ("FAIL " ++ name ++ ": " ++ displayException err)
                pure False
            Right () -> do
                putStrLn ("PASS " ++ name)
                pure True
    let failures = length (filter not results)
    putStrLn (show (length results - failures) ++ "/" ++ show (length results) ++ " tests passed")
    unless (failures == 0) exitFailure

tests :: [(String, IO ())]
tests =
    [("default chunk size is 4096", assertEqual "chunk size" 4096 defaultChunkSize)]
        ++ [("read " ++ show size ++ " bytes", checkRead (payload size) defaultChunkSize) | size <- boundarySizes]
        ++ [("copy " ++ show size ++ " bytes", checkCopy (payload size) defaultChunkSize) | size <- boundarySizes]
        ++ [("custom chunk size " ++ show size, testCustomChunkSize size) | size <- [1, 2, 17, 8192]]
        ++ [ ("nonempty short reads do not signal EOF", testShortReads)
           , ("empty read stops without invoking the step", testEmptyRead)
           , ("invalid sizes are rejected before I/O", testInvalidSizes)
           , ("read errors propagate after processing earlier data", testReadFailure)
           , ("step errors stop further reads", testStepFailure)
           , ("handle read and write errors propagate", testHandleErrors)
           , ("reading starts at the current handle position", testCurrentPosition)
           , ("many tiny chunks keep an accurate count", testManyChunks)
           ]

boundarySizes :: [Int]
boundarySizes = [0, 1, 4095, 4096, 4097, 8192, 8209]

-- Include every byte value, including NUL, newlines, and non-UTF-8 bytes.
payload :: Int -> BS.ByteString
payload size = BS.pack (take size (cycle [0 .. 255]))

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
    unless (actual == expected) $
        fail (label ++ ": expected " ++ show expected ++ ", got " ++ show actual)

expectIOException :: String -> IO a -> IO IOException
expectIOException label action = do
    result <- try (void action) :: IO (Either IOException ())
    case result of
        Left err -> pure err
        Right () -> fail (label ++ ": expected an IOException")

withTempHandle :: (Handle -> IO a) -> IO a
withTempHandle action = do
    directory <- getTemporaryDirectory
    bracket
        (openBinaryTempFile directory "read4k-test")
        (\(path, handle) -> hClose handle `finally` removeFile path)
        (action . snd)

withInput :: BS.ByteString -> (Handle -> IO a) -> IO a
withInput bytes action = withTempHandle $ \source -> do
    BS.hPut source bytes
    hSeek source AbsoluteSeek 0
    action source

checkRead :: BS.ByteString -> Int -> IO ()
checkRead input chunkSize = withInput input $ \source -> do
    actual <- readAllInChunks source chunkSize
    assertEqual "read data" input actual
    assertEqual "source remains open" True =<< hIsOpen source
    assertEqual "subsequent read at EOF" BS.empty =<< readAllInChunks source chunkSize

checkCopy :: BS.ByteString -> Int -> IO ()
checkCopy input chunkSize = withInput input $ \source ->
    withTempHandle $ \destination -> do
        count <- copyInChunks destination source chunkSize
        assertEqual "byte count" (fromIntegral (BS.length input)) count
        assertEqual "source remains open" True =<< hIsOpen source
        assertEqual "destination remains open" True =<< hIsOpen destination
        assertEqual "subsequent copy at EOF" 0 =<< copyInChunks destination source chunkSize
        hSeek destination AbsoluteSeek 0
        actual <- BS.hGetContents destination
        assertEqual "copied data" input actual

testCustomChunkSize :: Int -> IO ()
testCustomChunkSize chunkSize =
    forM_ [0, 1, chunkSize - 1, chunkSize, chunkSize + 1, 2 * chunkSize + 3] $ \size -> do
        checkRead (payload size) chunkSize
        checkCopy (payload size) chunkSize

-- An explicit EOF chunk is required; any attempt to read after it fails.
-- Return both the reader and a log of its requested chunk sizes.
scriptedReader :: [BS.ByteString] -> IO (Int -> IO BS.ByteString, IO [Int])
scriptedReader chunks = do
    remaining <- newIORef chunks
    requests <- newIORef []
    let readChunk chunkSize = do
            modifyIORef' requests (chunkSize :)
            next <- atomicModifyIORef' remaining $ \case
                [] -> ([], Nothing)
                chunk : more -> (more, Just chunk)
            case next of
                Nothing -> fail "read past EOF"
                Just chunk -> do
                    unless (BS.length chunk <= chunkSize) (fail "scripted chunk exceeds requested size")
                    pure chunk
    pure (readChunk, reverse <$> readIORef requests)

testShortReads :: IO ()
testShortReads = do
    let chunks = [BS.pack [0], BS.pack [255, 10], BS.pack [13, 128, 42]]
    (readChunk, requests) <- scriptedReader (chunks ++ [BS.empty])
    reversed <- foldChunks defaultChunkSize readChunk (\acc chunk -> pure (chunk : acc)) []
    assertEqual "all short chunks preserved in order" (BS.concat chunks) (BS.concat (reverse reversed))
    assertEqual "same maximum requested until EOF" (replicate 4 defaultChunkSize) =<< requests

testEmptyRead :: IO ()
testEmptyRead = do
    (readChunk, requests) <- scriptedReader [BS.empty]
    result <- foldChunks defaultChunkSize readChunk (\_ _ -> fail "step called at EOF") (0 :: Int)
    assertEqual "initial accumulator" 0 result
    assertEqual "one EOF read" [defaultChunkSize] =<< requests

testInvalidSizes :: IO ()
testInvalidSizes = withInput (payload 10) $ \source ->
    withTempHandle $ \destination -> do
        calls <- newIORef (0 :: Int)
        let readChunk _ = modifyIORef' calls (+ 1) >> pure (BS.singleton 0)
        forM_ [0, -1, minBound] $ \size -> do
            foldError <- expectIOException "fold" (foldChunks size readChunk (\_ _ -> fail "step called") ())
            readError <- expectIOException "read" (readAllInChunks source size)
            copyError <- expectIOException "copy" (copyInChunks destination source size)
            forM_ [foldError, readError, copyError] $ \err ->
                assertEqual "validation error" "chunk size must be greater than zero" (ioeGetErrorString err)
        assertEqual "reader was not called" 0 =<< readIORef calls
        assertEqual "source was not consumed" 0 =<< hTell source
        assertEqual "destination was not written" 0 =<< hTell destination

testReadFailure :: IO ()
testReadFailure = do
    calls <- newIORef (0 :: Int)
    processed <- newIORef []
    let chunk = payload 3
        readChunk _ = do
            call <- atomicModifyIORef' calls (\n -> (n + 1, n))
            if call == 0 then pure chunk else ioError (userError "read failed")
        step () bytes = modifyIORef' processed (bytes :)
    err <- expectIOException "read failure" (foldChunks defaultChunkSize readChunk step ())
    assertEqual "original read error" "read failed" (ioeGetErrorString err)
    assertEqual "data processed before error" [chunk] =<< readIORef processed
    assertEqual "no retries after error" 2 =<< readIORef calls

testStepFailure :: IO ()
testStepFailure = do
    (readChunk, requests) <- scriptedReader [payload 3, payload 2, BS.empty]
    err <-
        expectIOException "step failure" $
            foldChunks defaultChunkSize readChunk (\_ _ -> ioError (userError "write failed")) ()
    assertEqual "original step error" "write failed" (ioeGetErrorString err)
    assertEqual "no further reads after failed step" [defaultChunkSize] =<< requests

testHandleErrors :: IO ()
testHandleErrors = do
    withInput (payload 10) $ \source -> do
        hClose source
        _ <- expectIOException "closed source" (readAllInChunks source defaultChunkSize)
        withTempHandle $ \destination -> do
            _ <- expectIOException "copy from closed source" (copyInChunks destination source defaultChunkSize)
            pure ()
    withInput (payload 8209) $ \source ->
        withTempHandle $ \destination -> do
            hClose destination
            _ <- expectIOException "closed destination" (copyInChunks destination source defaultChunkSize)
            assertEqual "no further reads after failed write" (fromIntegral defaultChunkSize) =<< hTell source

testCurrentPosition :: IO ()
testCurrentPosition = withInput (payload 8209) $ \source -> do
    let offset = 123
        expected = BS.drop offset (payload 8209)
    hSeek source AbsoluteSeek (fromIntegral offset)
    assertEqual "read suffix" expected =<< readAllInChunks source defaultChunkSize
    hSeek source AbsoluteSeek (fromIntegral offset)
    withTempHandle $ \destination -> do
        count <- copyInChunks destination source defaultChunkSize
        assertEqual "suffix byte count" (fromIntegral (BS.length expected)) count
        hSeek destination AbsoluteSeek 0
        assertEqual "copied suffix" expected =<< BS.hGetContents destination

testManyChunks :: IO ()
testManyChunks = do
    let count = 20000
    (readChunk, requests) <- scriptedReader (replicate count (BS.singleton 255) ++ [BS.empty])
    actual <- foldChunks 1 readChunk (\total chunk -> pure (total + BS.length chunk)) (0 :: Int)
    assertEqual "total bytes" count actual
    assertEqual "one read per chunk plus EOF" (count + 1) . length =<< requests
