{-# LANGUAGE DeriveDataTypeable
           , ExistentialQuantification
           , GeneralizedNewtypeDeriving
  #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Diagrams.Attributes
-- Copyright   :  (c) 2011 diagrams-lib team (see LICENSE)
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  diagrams-discuss@googlegroups.com
--
-- Diagrams may have /attributes/ which affect the way they are
-- rendered.  This module defines some common attributes; particular
-- backends may also define more backend-specific attributes.
--
-- Every attribute type must have a /semigroup/ structure, that is, an
-- associative binary operation for combining two attributes into one.
-- Unless otherwise noted, all the attributes defined here use the
-- 'Last' structure, that is, combining two attributes simply keeps
-- the second one and throws away the first.  This means that child
-- attributes always override parent attributes.
--
-----------------------------------------------------------------------------

module Diagrams.Attributes (
  -- * Color
  -- $color

    Color(..), SomeColor(..)

  -- ** Line color
  , LineColor, getLineColor, lineColor, lc, lcA

  -- ** Fill color
  , FillColor, getFillColor, fillColor, fc, fcA

  -- ** Opacity
  , Opacity, getOpacity, opacity

  -- * Lines
  -- ** Width
  , LineWidth, getLineWidth, lineWidth, lw

  -- ** Cap style
  , LineCap(..), LineCapA, getLineCap, lineCap

  -- ** Join style
  , LineJoin(..), LineJoinA, getLineJoin, lineJoin

  -- ** Dashing
  , Dashing(..), DashingA, getDashing, dashing

  ) where

import Diagrams.Core

import Data.Colour
import qualified Data.Colour.SRGB as RGB

import Data.Typeable

import Data.Semigroup

------------------------------------------------------------
--  Color  -------------------------------------------------
------------------------------------------------------------

-- $color
-- Diagrams outsources all things color-related to Russell O\'Connor\'s
-- very nice colour package
-- (<http://hackage.haskell.org/package/colour>).  For starters, it
-- provides a large collection of standard color names.  However, it
-- also provides a rich set of combinators for combining and
-- manipulating colors; see its documentation for more information.

-- | The 'Color' type class encompasses color representations which
--   can be used by the Diagrams library.  Instances are provided for
--   both the 'Data.Colour.Colour' and 'Data.Colour.AlphaColour' types
--   from the "Data.Colour" library.
class Color c where
  -- | Convert a color to red, green, blue, and alpha channels in the
  --   range [0,1].
  colorToRGBA :: c -> (Double,Double,Double,Double)

-- | An existential wrapper for instances of the 'Color' class.
data SomeColor = forall c. Color c => SomeColor c
  deriving Typeable

-- | The color with which lines (strokes) are drawn.  Note that child
--   colors always override parent colors; that is, @'lineColor' c1
--   . 'lineColor' c2 $ d@ is equivalent to @'lineColor' c2 $ d@.
--   More precisely, the semigroup structure on line color attributes
--   is that of 'Last'.
newtype LineColor = LineColor (Last SomeColor)
  deriving (Typeable, Semigroup)
instance AttributeClass LineColor

getLineColor :: LineColor -> SomeColor
getLineColor (LineColor (Last c)) = c

-- | Set the line (stroke) color.  This function is polymorphic in the
--   color type (so it can be used with either 'Colour' or
--   'AlphaColour'), but this can sometimes create problems for type
--   inference, so the 'lc' and 'lcA' variants are provided with more
--   concrete types.
lineColor :: (Color c, HasStyle a) => c -> a -> a
lineColor = applyAttr . LineColor . Last . SomeColor

-- | A synonym for 'lineColor', specialized to @'Colour' Double@
--   (i.e. opaque colors).
lc :: HasStyle a => Colour Double -> a -> a
lc = lineColor

-- | A synonym for 'lineColor', specialized to @'AlphaColour' Double@
--   (i.e. colors with transparency).
lcA :: HasStyle a => AlphaColour Double -> a -> a
lcA = lineColor

-- | The color with which shapes are filled. Note that child
--   colors always override parent colors; that is, @'fillColor' c1
--   . 'fillColor' c2 $ d@ is equivalent to @'lineColor' c2 $ d@.
--   More precisely, the semigroup structure on fill color attributes
--   is that of 'Last'.
newtype FillColor = FillColor (Last SomeColor)
  deriving (Typeable, Semigroup)
instance AttributeClass FillColor

-- | Set the fill color.  This function is polymorphic in the color
--   type (so it can be used with either 'Colour' or 'AlphaColour'),
--   but this can sometimes create problems for type inference, so the
--   'fc' and 'fcA' variants are provided with more concrete types.
fillColor :: (Color c, HasStyle a) => c -> a -> a
fillColor = applyAttr . FillColor . Last . SomeColor

getFillColor :: FillColor -> SomeColor
getFillColor (FillColor (Last c)) = c

-- | A synonym for 'fillColor', specialized to @'Colour' Double@
--   (i.e. opaque colors).
fc :: HasStyle a => Colour Double -> a -> a
fc = fillColor

-- | A synonym for 'fillColor', specialized to @'AlphaColour' Double@
--   (i.e. colors with transparency).
fcA :: HasStyle a => AlphaColour Double -> a -> a
fcA = fillColor

instance (Floating a, Real a) => Color (Colour a) where
  colorToRGBA col = (r,g,b,1)
    where c' = RGB.toSRGB . colourConvert $ col
          r  = RGB.channelRed c'
          g  = RGB.channelGreen c'
          b  = RGB.channelBlue c'

instance (Floating a, Real a) => Color (AlphaColour a) where
  colorToRGBA col = (r,g,b,a)
    where col' = alphaColourConvert col
          a  = alphaChannel col'
          c' = RGB.toSRGB . alphaToColour $ col'
          r  = RGB.channelRed c'
          g  = RGB.channelGreen c'
          b  = RGB.channelBlue c'

instance Color SomeColor where
  colorToRGBA (SomeColor c) = colorToRGBA c

instance Color LineColor where
  colorToRGBA (LineColor (Last c)) = colorToRGBA c

instance Color FillColor where
  colorToRGBA (FillColor (Last c)) = colorToRGBA c

alphaToColour :: (Floating a, Ord a, Fractional a) => AlphaColour a -> Colour a
alphaToColour ac | alphaChannel ac == 0 = ac `over` black
                 | otherwise = darken (recip (alphaChannel ac)) (ac `over` black)

------------------------------------------------------------
-- Opacity

-- | Although the individual colors in a diagram can have
--   transparency, the opacity/transparency of a diagram as a whole
--   can be specified with the @Opacity@ attribute.  The opacity is a
--   value between 1 (completely opaque, the default) and 0
--   (completely transparent).  Opacity is multiplicative, that is,
--   @'opacity' o1 . 'opacity' o2 === 'opacity' (o1 * o2)@.  In other
--   words, for example, @opacity 0.8@ means \"decrease this diagram's
--   opacity to 80% of its previous opacity\".
newtype Opacity = Opacity (Product Double)
  deriving (Typeable, Semigroup)
instance AttributeClass Opacity

getOpacity :: Opacity -> Double
getOpacity (Opacity (Product d)) = d

-- | Multiply the opacity (see 'Opacity') by the given value.  For
--   example, @opacity 0.8@ means \"decrease this diagram's opacity to
--   80% of its previous opacity\".
opacity :: HasStyle a => Double -> a -> a
opacity = applyAttr . Opacity . Product

------------------------------------------------------------
--  Lines and stuff    -------------------------------------
------------------------------------------------------------

-- | The width of lines.  By default, the line width is measured with
--   respect to the /final/ coordinate system of a rendered diagram,
--   as opposed to the local coordinate systems in effect at the time
--   the line width was set for various subdiagrams.  This is so that
--   it is easy to combine a variety of shapes (some created by
--   scaling) and have them all drawn using a consistent line width.
--   However, sometimes it is desirable for scaling to affect line
--   width; the 'freeze' operation is provided for this purpose.  The
--   line width of frozen diagrams is affected by transformations.
--
--   Line widths specified on child nodes always override line widths
--   specified at parent nodes.
newtype LineWidth = LineWidth (Last Double)
  deriving (Typeable, Semigroup)
instance AttributeClass LineWidth

getLineWidth :: LineWidth -> Double
getLineWidth (LineWidth (Last w)) = w

-- | Set the line (stroke) width.
lineWidth :: HasStyle a => Double -> a -> a
lineWidth = applyAttr . LineWidth . Last

-- | A convenient synonym for 'lineWidth'.
lw :: HasStyle a => Double -> a -> a
lw = lineWidth

-- | What sort of shape should be placed at the endpoints of lines?
data LineCap = LineCapButt   -- ^ Lines end precisely at their endpoints.
             | LineCapRound  -- ^ Lines are capped with semicircles
                             --   centered on endpoints.
             | LineCapSquare -- ^ Lines are capped with a squares
                             --   centered on endpoints.
  deriving (Eq,Show,Typeable)

newtype LineCapA = LineCapA (Last LineCap)
  deriving (Typeable, Semigroup)
instance AttributeClass LineCapA

getLineCap :: LineCapA -> LineCap
getLineCap (LineCapA (Last c)) = c

-- | Set the line end cap attribute.
lineCap :: HasStyle a => LineCap -> a -> a
lineCap = applyAttr . LineCapA . Last


-- | How should the join points between line segments be drawn?
data LineJoin = LineJoinMiter    -- ^ Use a \"miter\" shape (whatever that is).
              | LineJoinRound    -- ^ Use rounded join points.
              | LineJoinBevel    -- ^ Use a \"bevel\" shape (whatever
                                 --   that is).  Are these...
                                 --   carpentry terms?
  deriving (Eq,Show,Typeable)

newtype LineJoinA = LineJoinA (Last LineJoin)
  deriving (Typeable, Semigroup)
instance AttributeClass LineJoinA

getLineJoin :: LineJoinA -> LineJoin
getLineJoin (LineJoinA (Last j)) = j

-- | Set the segment join style.
lineJoin :: HasStyle a => LineJoin -> a -> a
lineJoin = applyAttr . LineJoinA . Last

-- | Create lines that are dashing... er, dashed.
data Dashing = Dashing [Double] Double
  deriving Typeable

newtype DashingA = DashingA (Last Dashing)
  deriving (Typeable, Semigroup)
instance AttributeClass DashingA

getDashing :: DashingA -> Dashing
getDashing (DashingA (Last d)) = d

-- | Set the line dashing style.
dashing :: HasStyle a =>
           [Double]  -- ^ A list specifying alternate lengths of on
                     --   and off portions of the stroke.  The empty
                     --   list indicates no dashing.
        -> Double    -- ^ An offset into the dash pattern at which the
                     --   stroke should start.
        -> a -> a
dashing ds offs = applyAttr (DashingA (Last (Dashing ds offs)))
