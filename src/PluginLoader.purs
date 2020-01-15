module PluginLoader
       ( pluginLoader )   
       where

import Prelude (Unit, bind, discard, pure, unit, ($), (<>))
import Effect ( Effect)
import Effect.Exception ( try)
import Data.Show (show)
import Data.String.Pattern (Pattern(..))
import Data.String.Common (split, trim)
import Type.Proxy (Proxy(..))
import Posix.Dlfcn (dlopen,dlsym,DLObjects)
import Network.TcpServer (Socket, createServer, listen, onRead, read, write)
import Effect.Ref as Ref 
import Effect.Class (liftEffect)
import Data.Maybe  (Maybe(..))
import Data.Either (Either(..))

  
_EffectFct :: forall a. Proxy (a -> Effect String)
_EffectFct = Proxy

serve :: forall a. a -> Ref.Ref (Maybe DLObjects) -> Socket -> Effect Unit
serve arg objs socket = do
  s <- read socket
  r <- interp $ split (Pattern " ") $ trim s
  write socket $ r <> "\n"
  pure unit
  where
    interp :: Array String -> Effect String
    interp ["l", lib ] = do
      res <- try $ dlopen $ lib <> ".so"
      case res of
        Right dlobj -> do
          _ <- Ref.write (Just dlobj) objs
          pure $ "loaded " <> lib <> ".so"
        Left error -> pure $ show error
    interp ["c", fct] = do
      dlobj_ <- Ref.read objs
      case dlobj_ of
        Just dlobj -> do
          res <- try $ dlsym dlobj fct _EffectFct
          case res of
            Right f -> do
              res' <- try $ f arg
              case res' of
                Left error -> pure $ "error:" <> show error
                Right s -> pure s
            Left error -> pure $ show error
        Nothing -> pure "no object file loaded"
    interp _ = pure $ "l <file(.so)>  : load plugin\n"
                   <> "c <Module.fct> : call function"

pluginLoader :: forall a. Int -> a -> Effect Unit
pluginLoader port arg = do
  srv <- createServer port
  dlobj <- liftEffect (Ref.new Nothing)
  onRead srv $ serve arg dlobj
  listen srv
  pure unit              

