-- Copyright (C) 2013  Fraser Tweedale
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

{-# LANGUAGE TemplateHaskell #-}

module Crypto.JOSE.TH where

import Control.Applicative
import Data.Aeson
import Data.Char
import Language.Haskell.TH.Lib
import Language.Haskell.TH.Syntax


capitalize :: String -> String
capitalize (x:xs) = toUpper x:xs
capitalize s = s

sanitize :: String -> String
sanitize = map (\c -> if isAlphaNum c then c else '_')

conize :: String -> Name
conize = mkName . capitalize . sanitize

guardPred :: String -> ExpQ
guardPred s = [e| $(varE $ mkName "s") == s |]

guardExp :: String -> ExpQ
guardExp s = [e| pure $(conE $ conize s) |]

guard :: String -> Q (Guard, Exp)
guard s = normalGE (guardPred s) (guardExp s)

endGuardPred :: ExpQ
endGuardPred = [e| otherwise |]

endGuardExp :: ExpQ
endGuardExp = [e| fail "unrecognised value" |]

endGuard :: Q (Guard, Exp)
endGuard = normalGE endGuardPred endGuardExp

guardedBody :: [String] -> BodyQ
guardedBody vs = guardedB (map guard vs ++ [endGuard])

parseJSONClauseQ :: [String] -> ClauseQ
parseJSONClauseQ vs = clause [varP $ mkName "s"] (guardedBody vs) []

parseJSONFun :: [String] -> DecQ
parseJSONFun vs = funD 'parseJSON [parseJSONClauseQ vs]


toJSONClause :: String -> ClauseQ
toJSONClause s = clause [conP (conize s) []] (normalB [| s |]) []

toJSONFun :: [String] -> DecQ
toJSONFun vs = funD 'toJSON (map toJSONClause vs)


aesonInstance :: String -> Name -> TypeQ
aesonInstance s n = appT (conT n) (conT $ mkName s)

deriveJOSEType :: String -> [String] -> Q [Dec]
deriveJOSEType s vs = sequenceQ [
  dataD (cxt []) (mkName s) [] (map conQ vs) (map mkName ["Eq", "Show"])
  , instanceD (cxt []) (aesonInstance s ''FromJSON) [parseJSONFun vs]
  , instanceD (cxt []) (aesonInstance s ''ToJSON) [toJSONFun vs]
  ]
  where
    conQ v = normalC (conize v) []
