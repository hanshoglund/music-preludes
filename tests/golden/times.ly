\include "lilypond-book-preamble.ly"
\paper {
  #(define dump-extents #t)

  indent = 0\mm
  line-width = 210\mm - 2.0 * 0.4\in
  ragged-right = ##t
  force-assignment = #""
  line-width = #(- line-width (* mm  3.000000))
}
\header {
  title = ""
  composer = ""
}
\layout {
}

<<
    \new Staff {   \set Staff.instrumentName = "" \set Staff.shortInstrumentName = "" \time 4/4 \clef treble {   c'16( d'16 e'16 cis'16 dis'16 eis'16) c'16( d'16 e'16 cis'16 dis'16 eis'16) c'16( d'16 e'16 cis'16
                                                                                                             } \time 2/4 dis'16 eis'16) c'16( d'16 e'16 cis'16 dis'16 eis'16)
               }
>>