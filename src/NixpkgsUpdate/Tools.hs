{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module NixpkgsUpdate.Tools where

import Data.Foldable (fold)
import qualified Data.Text as T
import Data.Traversable (for)
import Language.Haskell.TH.Lib
import Language.Haskell.TH.Syntax (mkName)
import OurPrelude
import System.Environment

concat <$> for ["gist", "git", "nix", "nixpkgs-review", "timeout", "tree"] \tool ->
  case T.splitOn "-" $ T.pack tool of
    [] -> fail "splitOn should not ever do this"
    toolHead : toolTail -> do
      let camelTool = fold $ toolHead : map T.toTitle toolTail
          upperTool = T.toUpper camelTool
          name = mkName $ T.unpack camelTool
      envVarValue <- liftIO $ lookupEnv $ T.unpack upperTool
      sequence
        [ -- name :: String
          sigD name [t|String|],
          -- name = "tool"
          -- name = "/nix/store/.../bin/tool"
          valD (varP name) (normalB $ stringE $ maybe tool (++ "/bin/" ++ tool) envVarValue) []
        ]

nixBuild :: String
nixBuild = nix ++ "-build"

nixShell :: String
nixShell = nix ++ "-shell"
