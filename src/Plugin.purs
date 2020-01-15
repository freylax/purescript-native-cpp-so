module Plugin where

import Prelude
import Effect ( Effect)

import Effect.Ref as Ref

add :: Ref.Ref Int -> Effect String
add i' = do
  i <- Ref.read i'
  _ <- Ref.write (i + 1) i'
  pure $ (show i) <> " -> " <> (show $ i + 1)
  
  

       
