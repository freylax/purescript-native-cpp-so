module Main where

import Prelude
import Effect ( Effect)
import Effect.Console ( log)
import Effect.Exception ( Error, message, catchException)
import Effect.Class ( liftEffect)
import Type.Proxy (Proxy(..))
import Posix.Dlfcn (dlopen,dlsym)
import Effect.Ref as Ref 

printError :: Error -> Effect Unit
printError e = do
  log $ "Error: " <> message e
  pure unit
  
_EffectFct :: Proxy (Ref.Ref Int -> Effect String)
_EffectFct = Proxy

main :: Effect Unit
main = catchException printError
   do
     -- our working data
     i <- liftEffect (Ref.new 0)
     -- open shared object file
     dlobj <- dlopen "plugin.so"         
     -- get symbol Plugin.add
     add <- dlsym dlobj "Plugin.add" _EffectFct
     add i >>= log
     add i >>= log
     
       
