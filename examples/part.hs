
import Music.Prelude.Basic
import Data.AffineSpace.Relative

open = openLy . asScore
main = do
    return $ asScore score
    -- writeMidi "test.mid" score
    -- writeXml "test.xml" $ score^/4
    openXml score
    -- openLy score
    -- playMidiIO "Graphic MIDI" $ score^/10

{-    
    Pärt: Cantus in Memory of Benjamin Britten
    Copied from Abjad
-}

-- TODO tempo
-- TODO 6/4

score = meta $ dynamics ppp $ before 30 (bell <> delay 6 strings)
    where
        meta = title "Cantus in Memoriam Benjamin Britten" . composer "Arvo Pärt"

withTintin :: Pitch -> Score Note -> Score Note
withTintin p x = x <> tintin p x

-- | Given the melody voice return the tintinnabular voice.
tintin :: Pitch -> Score Note -> Score Note
tintin tonic = modifyPitch (relative tonic tintin')

-- | 
-- Given the melody interval (relative tonic), returns the tintinnabular voice interval. 
--
-- That is return the highest interval that is a member of the tonic minorTriad in any octave
-- which is also less than the given interval 
--
tintin' :: Interval -> Interval
tintin' melInterval 
    | isNegative melInterval = error "tintin: Negative interval"
    | otherwise = last $ takeWhile (< melInterval) $ tintinNotes
    where
        tintinNotes = concat $ iterate (fmap (+ _P8)) minorTriad
        minorTriad = [_P1,m3,_P5]


bell :: Score Note
bell = let
    cue = stretchTo 1 (rest |> a) 
    in text "l.v." $ removeRests $ times 40 $ scat [times 3 $ scat [cue,rest], rest^*2]

fallingScale = [a',g'..a_]
fallingScaleSect n = {-fmap (annotate (show n)) $-} take n $ fallingScale
mainSubject = stretch (1/6) $ asScore $ scat $ mapEvensOdds (accent . (^*2)) id $ concatMap fallingScaleSect [1..30]

strings :: Score Note
strings = let
    vln1 = setClef GClef $ setPart 1 $ octavesUp   1 $ cue
    vln2 = setClef GClef $ setPart 2 $ octavesDown 0 $ stretch 2 cue
    vla  = setClef CClef $ setPart 3 $ octavesDown 1 $ stretch 4 cue
    vc   = setClef FClef $ setPart 4 $ octavesDown 2 $ stretch 8 cue
    db   = setClef FClef $ setPart 5 $ octavesDown 3 $ stretch 16 cue
    in vln1 <> vln2 <> vla <> vc <> db
    where
        cue = delay (1/2) $ withTintin (octavesDown 4 a) mainSubject



mapEvensOdds :: (b -> a) -> (b -> a) -> [b] -> [a]
mapEvensOdds f g xs = let
    evens = fmap (xs !!) [0,2..]
    odds = fmap (xs !!) [1,3..]
    merge xs ys = concatMap (\(x,y) -> [x,y]) $ xs `zip` ys
    in take (length xs) $ map f evens `merge` map g odds
