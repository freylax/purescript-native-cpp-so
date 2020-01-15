module Network.TcpServer where

import Effect ( Effect )
import Data.Unit ( Unit)
  
foreign import data Socket :: Type
foreign import data Server :: Type

foreign import write :: Socket -> String -> Effect Unit
foreign import read :: Socket -> Effect String
foreign import closeSocket :: Socket -> Effect Unit

foreign import createServer :: Int -> Effect Server

foreign import onRead :: Server -> (Socket -> Effect Unit) -> Effect Unit
foreign import listen :: Server -> Effect Unit
       
