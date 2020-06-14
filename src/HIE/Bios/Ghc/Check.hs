module HIE.Bios.Ghc.Check (
    checkSyntax
  , check
  ) where

import GHC (DynFlags(..), GhcMonad)
import Exception

import HIE.Bios.Environment
import HIE.Bios.Ghc.Api
import HIE.Bios.Ghc.Logger
import qualified HIE.Bios.Internal.Log as Log
import HIE.Bios.Types
import HIE.Bios.Ghc.Load
import Control.Monad.IO.Class

import System.IO.Unsafe (unsafePerformIO)
import qualified HIE.Bios.Ghc.Gap as Gap

import qualified DynFlags as G
import qualified GHC as G
import HIE.Bios.Environment

----------------------------------------------------------------

-- | Checking syntax of a target file using GHC.
--   Warnings and errors are returned.
checkSyntax :: Show a
            => Cradle a
            -> [FilePath]  -- ^ The target files.
            -> IO String
checkSyntax _      []    = return ""
checkSyntax cradle files = do
    libDir <- getRuntimeGhcLibDir cradle False
    G.runGhcT libDir $ do
      Log.debugm $ "Cradle: " ++ show cradle
      res <- initializeFlagsWithCradle (head files) cradle
      case res of
        CradleSuccess (ini, _) -> do
          _sf <- ini
          either id id <$> check files
        CradleFail ce -> liftIO $ throwIO ce
        CradleNone -> return "No cradle"


  where
    {-
    sessionName = case files of
      [file] -> file
      _      -> "MultipleFiles"
      -}

----------------------------------------------------------------

-- | Checking syntax of a target file using GHC.
--   Warnings and errors are returned.
check :: (GhcMonad m)
      => [FilePath]  -- ^ The target files.
      -> m (Either String String)
check fileNames = do
  libDir <- G.topDir <$> G.getDynFlags
  withLogger (setAllWarningFlags libDir) $ setTargetFiles (map dup fileNames)

dup :: a -> (a, a)
dup x = (x, x)

----------------------------------------------------------------

-- | Set 'DynFlags' equivalent to "-Wall".
setAllWarningFlags :: FilePath -> DynFlags -> DynFlags
setAllWarningFlags libDir df = df { warningFlags = allWarningFlags libDir }

{-# NOINLINE allWarningFlags #-}
allWarningFlags :: FilePath -> Gap.WarnFlags
allWarningFlags libDir = unsafePerformIO $
    G.runGhcT (Just libDir) $ do
        df <- G.getSessionDynFlags
        (df', _) <- addCmdOpts ["-Wall"] df
        return $ G.warningFlags df'
