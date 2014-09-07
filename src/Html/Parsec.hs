{-# LANGUAGE OverloadedStrings, NoMonomorphismRestriction #-}
module HTML.Parsec
    ( parseHtml
    ) where

import Control.Monad (liftM)

import qualified Data.Text as T
import Text.Parsec
import Text.Parsec.Text

import qualified Data.HashMap.Strict as HM

import Dom

parseHtml :: T.Text -> Either ParseError Node
parseHtml s = case parse parseNodes "" s of
              Left err -> Left err
              Right nodes -> Right $
                -- FIXME: this is consistant with Robinson's setup, but will skip adding the html element
                -- if the DOM happens to be a single tree
                if length nodes == 1
                then head nodes
                else Dom.elem "html" HM.empty nodes

parseNodes = manyTill parseNode eof


parseNode = parseElement <|> parseText

parseText = liftM Dom.text $ many (noneOf "<")

parseElement = do
    -- opening tag
    (tag, attrs) <- between (char '<') (char '>') tagData
    -- contents
    children <- parseChildren
    -- closing tag
    string $ tag ++ ">" -- "</" is consumed by parseChildren, maybe bad form?
    return $ Dom.elem tag attrs children


parseChildren = spaces >> manyTill parseChild end
  where
    end = eof <|> (try (string "</") >> return ())

    parseChild = spacesAfter parseNode


tagData = do
    t <- tagName
    attrs <- attributes
    return (t,attrs)

tagName = many1 alphaNum

--this is safe because attribute will fail without consuming on '>''
attributes = liftM HM.fromList $ spaces >> many (spacesAfter attribute)

attribute = do
    name <- tagName
    char '='
    open <- char '"' <|> char '\''
    value <- many (noneOf [open])
    return (name, value)


-- run parser p and then strip the trailing spaces, returning the result of p.
spacesAfter p = p <* spaces