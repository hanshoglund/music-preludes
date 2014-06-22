
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}

{-
  Basic Scheme bindings
  
  For examples, see test1.scm (TODO write more)
  
  Requires husk-scheme to be in your path
    http://hackage.haskell.org/package/husk-scheme
-}
module Main where
 
import Music.Prelude
import Language.Scheme.Core
import Language.Scheme.Types
import Language.Scheme.Variables
import Language.Scheme.Parser
import Data.Traversable
import System.IO.Unsafe
import Data.IORef
import Data.Maybe
import Data.Either
import qualified Music.Score as Score
import qualified Data.Map as Map
-- import qualified Data.List
-- import System.Random

type LispScore = Score Integer
instance AffineSpace Integer where
  type Diff Integer = Integer
  (.-.) = (-)
  (.+^) = (+)

lispApi = [
  ("c", toLisp (c :: LispScore)),
  ("d", toLisp (d :: LispScore)),
  ("e", toLisp (e :: LispScore)),
  ("f", toLisp (f :: LispScore)),
  ("g", toLisp (g :: LispScore)),
  ("a", toLisp (a :: LispScore)),
  ("b", toLisp (b :: LispScore)),

  ("c#", toLisp (cs :: LispScore)),
  ("d#", toLisp (ds :: LispScore)),
  ("e#", toLisp (es :: LispScore)),
  ("f#", toLisp (fs :: LispScore)),
  ("g#", toLisp (gs :: LispScore)),
  ("a#", toLisp (as :: LispScore)),
  ("b#", toLisp (bs :: LispScore)),

  ("cb", toLisp (cb :: LispScore)),
  ("db", toLisp (db :: LispScore)),
  ("eb", toLisp (eb :: LispScore)),
  ("fb", toLisp (fb :: LispScore)),
  ("gb", toLisp (gb :: LispScore)),
  ("ab", toLisp (ab :: LispScore)),
  ("bb", toLisp (bb :: LispScore)),

  ("m3", toLisp (m3 :: Integer)),
  ("M3", toLisp (_M3 :: Integer)),
  ("up",       CustFunc $ lift2 (up   :: Integer -> LispScore -> LispScore)),

  -- ("ff", toLisp (fff :: Sum Double)),
  -- ("level",    CustFunc $ lift2 (up   :: Sum Double -> LispScore -> LispScore)),


  ("times",    CustFunc $ lift2 (times   :: Int -> LispScore -> LispScore)),
  ("stretch",  CustFunc $ lift2 (stretch :: Duration -> LispScore -> LispScore)),
  ("compress", CustFunc $ lift2 (compress :: Duration -> LispScore -> LispScore)),
  ("move",     CustFunc $ lift2 (delay   :: Duration -> LispScore -> LispScore)),

  ("scat",    CustFunc $ liftV (scat   :: [LispScore] -> LispScore)),
  ("pcat",    CustFunc $ liftV (pcat   :: [LispScore] -> LispScore)),
  ("rcat",    CustFunc $ liftV (rcat   :: [LispScore] -> LispScore)),

  ("|>",      CustFunc $ lift2 ((|>) :: LispScore -> LispScore -> LispScore)),
  ("<>",      CustFunc $ lift2 ((|>) :: LispScore -> LispScore -> LispScore)),
  ("</>",     CustFunc $ lift2 ((</>) :: LispScore -> LispScore -> LispScore)),

  ("first-argument",  CustFunc $ \(x : _) -> return x),
  ("second-argument", CustFunc $ \(_ : x : _) -> return x)
  ]



main = do
  stdEnv <- r5rsEnv
  env <- extendEnv stdEnv (map (over _1 (varNamespace,)) $ lispApi)
  code <- readFile "examples/test1.scm"
  res <- evalLisp' env $ fromRight $ readExpr code
  let sc = (\x -> x :: LispScore) $ fromJust $ fromRight $ fmap fromLisp $ res
  -- printScore sc
  openLilypond $ fmap (\x -> PartT(mempty::Part,TieT(mempty,ArticulationT(mempty::(Sum Double,Sum Double),DynamicT(mempty::Sum Double,[x]))))) $ sc
  return ()

printScore = mapM_ print . view notes
fromRight (Right x) = x  


class HasLisp a where
  _unlisp :: Prism' LispVal a

toLisp :: HasLisp a => a -> LispVal
toLisp = view (re _unlisp)

fromLisp :: HasLisp a => LispVal -> Maybe a
fromLisp = preview _unlisp

instance HasLisp Bool where
  _unlisp = prism' Bool $ \x -> case x of
    Bool x -> Just x
    _      -> Nothing

instance HasLisp Int where
  _unlisp = prism' (Number . toInteger) $ \x -> case x of
    Number x -> Just (fromInteger x)
    _        -> Nothing

instance HasLisp Integer where
  _unlisp = prism' Number $ \x -> case x of
    Number x -> Just x
    _        -> Nothing

-- instance HasLisp Pitch where
  -- _unlisp = _unlisp . iso ((c.+^) . spell usingSharps . fromInteger) (toInteger.semitones.(.-. c))

instance HasLisp Rational where
  _unlisp = prism' Rational $ \x -> case x of
    Number   x -> Just (fromIntegral x)
    Rational x -> Just x
    Float    x -> Just (realToFrac x)
    _       -> Nothing

instance HasLisp Double where
  _unlisp = prism' Float $ \x -> case x of
    Number x   -> Just (fromIntegral x)
    Rational x -> Just (fromRational x)
    Float x    -> Just x
    _          -> Nothing

instance HasLisp Duration where
  _unlisp = _unlisp . rationalFrac

instance HasLisp Time where
  _unlisp = _unlisp . rationalFrac

instance HasLisp Span where
  _unlisp = _unlisp . from delta

instance HasLisp a => HasLisp (Score.Note a) where
  _unlisp = _unlisp . note

instance HasLisp a => HasLisp (Score a) where
  _unlisp = _unlisp . from unsafeNotes

instance (HasLisp a, HasLisp b) => HasLisp (a, b) where
  _unlisp = prism' (lcons . over _1 toLisp . over _2 toLisp) $ \xs -> case xs of
      DottedList [x] y -> case (fromLisp x, fromLisp y) of
        (Just x, Just y) -> Just (x, y)
        _                -> Nothing
      _                -> Nothing                          
    where
      lcons (x, y) = DottedList [x] y

instance HasLisp a => HasLisp [a] where
  _unlisp = prism' (List . map toLisp) $ \xs -> case xs of
    List xs -> sequenceA $ map fromLisp $ xs
    _       -> Nothing

-- instance HasLisp Double where
  -- _unlisp = _unlisp . iso fromInteger (toInteger.round)

type LispFunc = [LispVal] -> IOThrowsError LispVal

liftV :: (HasLisp a, HasLisp b) => ([a] -> b) -> LispFunc
liftV f as = case (sequenceA $ map fromLisp as) of
  (Just as) -> return $ toLisp $ f as
  _         -> fail $ "Type error: got " ++ show as

lift1 :: (HasLisp a, HasLisp b) => (a -> b) -> LispFunc
lift1 f [a1] = case (fromLisp a1) of
  (Just a1) -> return $ toLisp $ f a1
  _         -> fail $ "Type error: got " ++ show a1
lift1 f _ = fail "Wrong number of args"

lift2 :: (HasLisp a, HasLisp b, HasLisp c) => (a -> b -> c) -> LispFunc
lift2 f [a1, a2] = case (fromLisp a1, fromLisp a2) of
  (Just a1, Just a2) -> return $ toLisp $ f a1 a2
  _                  -> fail "Type error"
lift2 f _ = fail "Wrong number of args"
  
-- lift2 :: (a -> b -> c) -> LispFunc


{-
makeEnv :: [(String, LispFunc)] -> Env -> Env
makeEnv bindings = composed $ map (uncurry extendEnv2 . fmap CustFunc) $ bindings
  where
composed = foldr (.) id

extendEnv2 :: String -> LispVal -> Env -> Env
extendEnv2 k v p = Environment (Just p) (retR $ toMap ("_" ++ k) (retR v)) (retR mempty) 
  where
    toMap k v = Map.insert k v mempty
      
    retR :: a -> IORef a
    retR = unsafePerformIO . newIORef
-}


doubleFrac = iso fromDouble toDouble
    where
      toDouble :: Real a => a -> Double
      toDouble = realToFrac

      fromDouble :: Fractional a => Double -> a
      fromDouble = realToFrac

rationalFrac = iso fromRational toRational
integInteg   = iso fromInteger toInteger
