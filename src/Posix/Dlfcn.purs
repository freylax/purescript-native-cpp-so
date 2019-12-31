module Posix.Dlfcn
       ( DLObjects,
         dlopen,
         dlsym ) where

import Effect ( Effect)
import Type.Proxy ( Proxy)
import Data.Unit ( Unit)

-- | Handle for loaded shared objects
foreign import data DLObjects  :: Type

-- | Load the shared objects from given filename.
foreign import dlopen :: String -> Effect DLObjects

-- | Get the value of the symbol by providing the
-- | handle for the shared objects, the full qualified
-- | name (Module.object...) and Type using the Proxy. 
foreign import dlsym :: forall a . DLObjects -> String -> Proxy a -> Effect a

-- | close the handle
foreign import dlclose :: DLObjects -> Effect Unit 
