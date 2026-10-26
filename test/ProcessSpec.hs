{-# LANGUAGE OverloadedStrings #-}

module ProcessSpec where

import OurPrelude
import qualified Process as P
import qualified System.Process.Typed as TP
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  let testProc = TP.shell "whatever"
  let runTestProc input = run . runError @TP.ExitCodeException . P.runPure input

  describe "read_" do
    it "gives Left with ExitCodeException under runPure with ExitFailure" do
      let result = runTestProc [(ExitFailure 1, "", "")] (P.read_ testProc)
      first TP.eceExitCode result `shouldBe` Left (ExitFailure 1)

  describe "ReadInterleaved" do
    it "concatenates stdout and stderr under runPure" do
      let result = runTestProc [(ExitSuccess, "foo", "bar")] (P.readInterleaved testProc)
      first TP.eceExitCode result `shouldBe` Right (ExitSuccess, "foobar")
