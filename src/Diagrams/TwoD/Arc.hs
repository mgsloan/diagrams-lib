{-# LANGUAGE TypeFamilies
           , ViewPatterns
  #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Diagrams.TwoD.Arc
-- Copyright   :  (c) 2011 diagrams-lib team (see LICENSE)
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  diagrams-discuss@googlegroups.com
--
-- Two-dimensional arcs, approximated by cubic bezier curves.
--
-----------------------------------------------------------------------------

module Diagrams.TwoD.Arc
    ( arc
    , arcT
    , bezierFromSweep

    , wedge
    ) where

import Diagrams.Core

import Diagrams.Coordinates
import Diagrams.Path
import Diagrams.Segment
import Diagrams.TwoD.Transform
import Diagrams.TwoD.Types
import Diagrams.TwoD.Vector (unitX, e)
import Diagrams.Util ((#), tau)

import Data.Semigroup ((<>))
import Data.VectorSpace((^-^), (*^), negateV)

-- For details of this approximation see:
--   http://www.tinaja.com/glib/bezcirc2.pdf

-- | @bezierFromSweepQ1 s@ constructs a 'Cubic' segment that starts in
--   the positive y direction and sweeps counterclockwise through @s@
--   radians.  The approximation is only valid for angles in the first
--   quadrant.
bezierFromSweepQ1 :: Rad -> Segment R2
bezierFromSweepQ1 s = fmap (^-^ v) . rotate (s/2) $ Cubic c2 c1 p0
  where p0@(coords -> x :& y) = rotate (s/2) v
        c1                    = ((4-x)/3)  &  ((1-x)*(3-x)/(3*y))
        c2                    = reflectY c1
        v                     = unitX

-- | @bezierFromSweep s@ constructs a series of 'Cubic' segments that
--   start in the positive y direction and sweep counter clockwise
--   through @s@ radians.  If @s@ is negative, it will start in the
--   negative y direction and sweep clockwise.  When @s@ is less than
--   0.0001 the empty list results.  If the sweep is greater than tau
--   then it is truncated to tau.
bezierFromSweep :: Rad -> [Segment R2]
bezierFromSweep s
  | s > tau    = bezierFromSweep tau
  | s < 0      = fmap reflectY . bezierFromSweep $ (-s)
  | s < 0.0001 = []
  | s < tau/4  = [bezierFromSweepQ1 s]
  | otherwise  = bezierFromSweepQ1 (tau/4)
          : map (rotateBy (1/4)) (bezierFromSweep (max (s - tau/4) 0))

{-
~~~~ Note [segment spacing]

There are a few obvious options for segment spacing:
   A. Evenly space segments each with sweep less than or equal
      to one quarter of a circle.  This has the benefit of a better approximation
      (at least I think it is better).
   B. Use as much of the sweep in quarter-circle sized segments and one for
      the remainder.  This potentially gives more opportunities for
      consistency (though not as much as option C) as the error in
      approximation would more often match the error from another arc
      in the diagram.
   C. Like option B but fixing the orientation and having a remnant at
      the beginning and the end.

Option B is implemented and this note is for posterity if anyone comes
across a situation with large enough arcs that they can actually see
the approximation error.
-}

arcT :: Angle a => a -> a -> Trail R2
arcT start end = Trail bs (sweep >= tau)
  where sweep = convertAngle $ end - start
        bs    = map (rotate start) . bezierFromSweep $ sweep

-- | Given a start angle @s@ and an end angle @e@, @'arc' s e@ is the
--   path of a radius one arc counterclockwise between the two angles.
arc :: (Angle a, PathLike p, V p ~ R2) => a -> a -> p
arc start end = pathLike (rotate start $ p2 (1,0))
                         False
                         (trailSegments $ arcT start end)

-- | Create a circular wedge of the given radius, beginning at the
--   first angle and extending counterclockwise to the second.
wedge :: (Angle a, PathLike p, V p ~ R2) => Double -> a -> a -> p
wedge r a1 a2 = pathLikeFromTrail $ fromOffsets [r *^ e a1]
                                 <> arc a1 a2 # scale r
                                 <> fromOffsets [r *^ negateV (e a2)]
