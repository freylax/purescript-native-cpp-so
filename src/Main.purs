module Main where

import Prelude
import Effect ( Effect)
import Effect.Console ( log)
import Effect.Exception ( Error, message, catchException)
import Type.Proxy (Proxy(..))
import Posix.Dlfcn (dlopen,dlsym)

printError :: Error -> Effect Unit
printError e = do
  log $ "Error: " <> message e
  pure unit
  
_StringFct :: Proxy (String -> String)
_StringFct = Proxy

main :: Effect Unit
main = catchException printError
   do
     -- open shared object file
     dlobj <- dlopen "plugin.so"         
     -- get symbol Plugin.foo
     foo <- dlsym dlobj "Plugin.foo" _StringFct 
     log (foo "Hello")
       
