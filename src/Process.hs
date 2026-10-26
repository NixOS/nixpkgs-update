{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Process where

import qualified Data.ByteString.Lazy as BSL
import Data.Maybe (fromMaybe)
import Polysemy
import Polysemy.Error (Error, throw)
import Polysemy.Input
import System.Exit (ExitCode (..))
import qualified System.Process.Typed as TP
import Prelude hiding (read)

data Process m a where
  Read :: TP.ProcessConfig stdin stdout stderr -> Process m (ExitCode, BSL.ByteString, BSL.ByteString)
  ReadInterleaved :: TP.ProcessConfig stdin stdout stderr -> Process m (ExitCode, BSL.ByteString)

makeSem ''Process

read_ ::
  (Members '[Process, Error TP.ExitCodeException] r) =>
  TP.ProcessConfig stdin stdout stderr ->
  Sem r (BSL.ByteString, BSL.ByteString)
read_ config = do
  (exitCode, out, err) <- read config
  case exitCode of
    ExitSuccess -> return (out, err)
    _ ->
      throw
        TP.ExitCodeException
          { TP.eceExitCode = exitCode,
            TP.eceProcessConfig =
              TP.setStdin TP.nullStream $
                TP.setStdout TP.nullStream $
                  TP.setStderr TP.nullStream $
                    config,
            TP.eceStdout = out,
            TP.eceStderr = err
          }

runIO ::
  (Member (Embed IO) r) =>
  Sem (Process ': r) a ->
  Sem r a
runIO =
  interpret $ \case
    Read config -> embed (TP.readProcess config)
    ReadInterleaved config -> embed (TP.readProcessInterleaved config)

runPure ::
  [(ExitCode, BSL.ByteString, BSL.ByteString)] ->
  Sem (Process ': r) a ->
  Sem r a
runPure outputList =
  runInputList outputList
    . reinterpret \case
      Read _config ->
        fromMaybe (ExitSuccess, "", "") <$> input
      ReadInterleaved _config -> do
        (exitCode, out, err) <- fromMaybe (ExitSuccess, "", "") <$> input
        return (exitCode, out <> err)
