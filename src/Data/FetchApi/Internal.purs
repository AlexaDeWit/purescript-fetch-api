module Data.FetchApi.Internal where

import Prelude
import Control.Bind (bindFlipped)
import Control.Monad.Error.Class (catchError)
import Control.Monad.Except.Trans (ExceptT(..), except)
import Control.Promise (Promise, toAffE)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode.Class (class DecodeJson, decodeJson)
import Data.Bifunctor (class Bifunctor, lmap, rmap)
import Data.Either (Either(..))
import Data.Function (applyFlipped)
import Data.Maybe (Maybe(..), maybe)
import Effect (Effect)
import Effect.Aff (Aff, catchError, try)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Exception (Error)

foreign import data FetchResponse :: Type

foreign import data FetchRequestInfoInternal :: Type

foreign import simpleFetchGetImpl :: String -> Effect (Promise FetchResponse)

foreign import fetchImpl :: FetchRequestInfoInternal -> String -> Effect (Promise FetchResponse)

foreign import extractJsonImpl :: FetchResponse -> Effect (Promise Json)

data FetchError
  = NetworkFailure Error
  | JsonParseError Error
  | DecodingFailed String

data FetchRequestInfo
  = FetchRequestInfo

-- | General HTTP Methods which support Response and Request bodies.
-- | HEAD and TRACE are intentionally omitted, as the functions to work
-- | With those request types will be defined intentionally differently.
-- | IE. There will be no function that can accept a HEAD request and then try to parse a response body.
data HttpMethod
  = GET
  | HEAD
  | POST
  | PUT
  | DELETE
  | CONNECT
  | OPTIONS
  | PATCH

makeFetchRequestInfoInternal :: FetchRequestInfo -> FetchRequestInfoInternal
makeFetchRequestInfoInternal = const $ fetchRequestInfo "hi"

foreign import fetchRequestInfo :: String -> FetchRequestInfoInternal

rawFetch :: String -> Maybe FetchRequestInfo -> ExceptT FetchError Aff FetchResponse
rawFetch url requestInfo =
  maybe simpleFetchGetImpl (makeFetchRequestInfoInternal >>> fetchImpl) requestInfo url
    # toAffE
    # try
    <#> lmap NetworkFailure
    # ExceptT

extractJson :: FetchResponse -> ExceptT FetchError Aff Json
extractJson response = extractJsonImpl response # toAffE # try <#> lmap NetworkFailure # ExceptT

fetchJson :: forall a. DecodeJson a => String -> Maybe FetchRequestInfo -> ExceptT FetchError Aff a
fetchJson url requestInfo =
  rawFetch url requestInfo >>= extractJson
    >>= ( decodeJson
          >>> lmap DecodingFailed
          >>> except
      )
