module Cheapskate.Types where
import Data.Sequence (Seq)
import Data.Default
import Data.Text (Text)
import qualified Data.Map as M

-- Structured representation of a document.

data Doc = Doc Options Blocks
           deriving Show

-- Block-level elements.
data Block = Para Inlines
           | Header Int Inlines
           | Blockquote Blocks
           | List Bool ListType [Blocks]
           | CodeBlock CodeAttr Text
           | HtmlBlock Text
           | HRule
           deriving Show

-- Attributes for fenced code blocks.  More structure
-- can be added later, or perhaps a catch-all to contain
-- the remainder of the line after the language.
data CodeAttr = CodeAttr { codeLang :: Maybe Text }
              deriving Show

data ListType = Bullet Char | Numbered NumWrapper Int deriving (Eq,Show)
data NumWrapper = PeriodFollowing | ParenFollowing deriving (Eq,Show)

-- Simple representation of HTML tag.
data HtmlTagType = Opening Text | Closing Text | SelfClosing Text deriving Show

-- We operate with sequences instead of lists, because
-- they allow more efficient appending on to the end.
type Blocks = Seq Block

-- Inline elements.
data Inline = Str Text
            | Space
            | SoftBreak
            | LineBreak
            | Emph Inlines
            | Strong Inlines
            | Code Text
            | Link Inlines Text {- URL -} Text {- title -}
            | Image Inlines Text {- URL -} Text {- title -}
            | Entity Text
            | RawHtml Text
            | Markdown Text -- Raw markdown to be parsed later.
            deriving Show

type Inlines = Seq Inline

type ReferenceMap = M.Map Text (Text, Text)

data Options = Options{
    sanitize           :: Bool  -- sanitize raw HTML, link/image attributes
  , allowRawHtml       :: Bool  -- allow raw HTML (if false it gets escaped)
  , preserveHardBreaks :: Bool  -- preserve hard line breaks in the source
  , debug              :: Bool  -- print container structure
  }
  deriving Show

instance Default Options where
  def = Options{
          sanitize = True
        , allowRawHtml = True
        , preserveHardBreaks = False
        , debug = False
        }
