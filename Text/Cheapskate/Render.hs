{-# LANGUAGE OverloadedStrings #-}
module Text.Cheapskate.Render (renderBlocks) where
import Text.Cheapskate.Types
import Data.Text (Text)
import Data.Char (isDigit, isHexDigit, isAlphaNum)
import qualified Text.Blaze.XHtml5 as H
import qualified Text.Blaze.Html5.Attributes as A
import qualified Text.Blaze.Html.Renderer.Text as BT
import Text.Blaze.Html hiding(contents)
import Data.Monoid
import Data.Foldable (foldMap, toList)
import qualified Data.Text as T
import Data.List (intersperse)

-- Render a sequence of blocks as HTML5.  Currently a single
-- newline is used between blocks, an a newline is used as a
-- separator e.g. for list items. These can be changed by adjusting
-- nl and blocksep.  Eventually we probably want these as parameters
-- or options.
renderBlocks :: Blocks -> Html
renderBlocks = mconcat . intersperse blocksep . map renderBlock . toList
  where renderBlock :: Block -> Html
        renderBlock (Header n ils)
          | n >= 1 && n <= 6 = ([H.h1,H.h2,H.h3,H.h4,H.h5,H.h6] !! (n - 1))
                                  $ renderInlines ils
          | otherwise        = H.p (renderInlines ils)
        renderBlock (Para ils) = H.p (renderInlines ils)
        renderBlock (HRule) = H.hr
        renderBlock (Blockquote bs) = H.blockquote $ nl <> renderBlocks bs <> nl
        renderBlock (CodeBlock attr t) =
          case codeLang attr of
                Nothing   -> base
                Just lang -> base ! A.class_ (toValue lang)
          where base = H.pre $ H.code $ toHtml (t <> "\n")
          -- add newline because Markdown.pl does
        renderBlock (List tight (Bullet _) items) =
          H.ul $ nl <> mapM_ (li tight) items
        renderBlock (List tight (Numbered _ n) items) =
          if n == 1 then base else base ! A.start (toValue n)
          where base = H.ol $ nl <> mapM_ (li tight) items
        renderBlock (HtmlBlock raw) = H.preEscapedToMarkup raw
        li :: Bool -> Blocks -> Html  -- tight list handling
        li True = (<> nl) . H.li . mconcat . intersperse blocksep .
                      map renderBlockTight . toList
        li False = toLi
        renderBlockTight (Para zs) = renderInlines zs
        renderBlockTight x         = renderBlock x
        toLi x = (H.li $ renderBlocks x) <> nl
        nl = "\n"
        blocksep = "\n"

-- Render a sequence of inlines as HTML5.
renderInlines :: Inlines -> Html
renderInlines = foldMap renderInline
  where renderInline :: Inline -> Html
        renderInline (Str t) = toHtml t
        renderInline Space   = " "
        renderInline SoftBreak = "\n" -- this preserves the line breaks in the
                                      -- markdown document; replace with " " if this
                                      -- isn't wanted.
        renderInline LineBreak = H.br <> "\n"
        renderInline (Emph ils) = H.em $ renderInlines ils
        renderInline (Strong ils) = H.strong $ renderInlines ils
        renderInline (Code t) = H.code $ toHtml t
        renderInline (Link ils url tit) =
          if T.null tit then base else base ! A.title (toValue' tit)
          where base = H.a ! A.href (toValue' url) $ renderInlines ils
        renderInline (Image ils url tit) =
          if T.null tit then base else base ! A.title (toValue' tit)
          where base = H.img ! A.src (toValue' url)
                             ! A.alt (toValue $ BT.renderHtml -- TODO strip tags
                                              $ renderInlines ils)
        renderInline (Entity t) = H.preEscapedToMarkup t
        renderInline (RawHtml t) = H.preEscapedToMarkup t
        renderInline (Markdown t) = toHtml t -- shouldn't happen

toValue' :: Text -> AttributeValue
toValue' = preEscapedToValue . gentleEscape . T.unpack

-- preserve existing entities
gentleEscape :: String -> String
gentleEscape [] = []
gentleEscape ('"':xs) = "&quot;" ++ gentleEscape xs
gentleEscape ('\'':xs) = "&#39;" ++ gentleEscape xs
gentleEscape ('&':'#':x:xs)
  | x == 'x' || x == 'X' =
  case span isHexDigit xs of
       (ys,';':zs) | not (null ys) && length ys < 6 ->
         '&':'#':x:ys ++ ";" ++ gentleEscape zs
       _ -> "&amp;#" ++ (x : gentleEscape xs)
gentleEscape ('&':'#':xs) =
  case span isDigit xs of
       (ys,';':zs) | not (null ys) && length ys < 6 ->
         '&':'#':ys ++ ";" ++ gentleEscape zs
       _ -> "&amp;#" ++ gentleEscape xs
gentleEscape ('&':xs) =
  case span isAlphaNum xs of
       (ys,';':zs) | not (null ys) && length ys < 11 ->
         '&':ys ++ ";" ++ gentleEscape zs
       _ -> "&amp;" ++ gentleEscape xs
gentleEscape (x:xs) = x : gentleEscape xs