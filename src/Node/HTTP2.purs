-- | Low-level bindings to the *Node.js* [HTTP/2](https://nodejs.org/docs/latest/api/http2.html) API.
module Node.HTTP2
  ( Headers
  , toHeaders
  , headerKeys
  , headerString
  , headerArray
  , headerStatus
  , OptionsObject
  , toOptions
  , Flags
  , toStringUTF8
  , fromStringUTF8
  )
  where

import Prelude

import Control.Monad.Except (runExcept)
import Data.Either (hush)
import Data.Maybe (Maybe)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Class (class MonadEffect, liftEffect)
import Foreign (Foreign, readArray, readInt, readString, unsafeToForeign)
import Foreign.Index (readProp)
import Foreign.Object (Object, keys)
import Node.Buffer (Buffer)
import Node.Buffer as Buffer
import Node.Encoding as Encoding
import Unsafe.Coerce (unsafeCoerce)

-- | HTTP headers object. Construct with the `toHeaders` function.
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#headers-object
foreign import data Headers :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#headers-object
-- |
-- | Use this function to construct a `Headers` object. Rules for `Headers`:
-- |
-- | > Headers are represented as own-properties on JavaScript objects.
-- | > The property keys will be serialized to lower-case.
-- | > Property values should be strings (if they are not they will
-- | > be coerced to strings) or an Array of strings (in order to send
-- | > more than one value per header field).
-- |
-- | This function provides no type-level enforcement of these rules.
-- |
-- | Example:
-- |
-- | ```
-- | toHeaders
-- |   { ":status": "200"
-- |   , "content-type": "text-plain"
-- |   , "ABC": ["has", "more", "than", "one", "value"]
-- |   }
-- | ```
toHeaders :: forall r. Record r -> Headers
toHeaders = unsafeCoerce

-- | Get all of the keys from a `Headers`.
-- |
-- | The value pointed to by each key may be either a `String`
-- | or an `Array String`.
headerKeys :: Headers -> Array String
headerKeys h = keys (unsafeCoerce h :: Object String)

-- | Try to read a `String` value from the `Headers` at the given key.
headerString :: Headers -> String -> Maybe String
headerString h n = hush $ runExcept do
  readString =<< readProp n (unsafeCoerce h)

-- | Try to read an `Array String` value from the `Headers` at the given key.
headerArray :: Headers -> String -> Maybe (Array String)
headerArray h n = hush $ runExcept do
  traverse readString =<< readArray =<< readProp n (unsafeCoerce h)

-- | https://nodejs.org/docs/latest/api/http2.html#headers-object
-- |
-- | > For incoming headers:
-- | >
-- | > * The `:status` header is converted to `number`.
headerStatus :: Headers -> Maybe Int
headerStatus h = hush $ runExcept do
  readInt =<< readProp ":status" (unsafeCoerce h)

-- | https://httpwg.org/specs/rfc7540.html#FrameHeader
type Flags = Int

-- | A type alias for `Foreign` which represents an `Object` with option properties.
-- |
-- | The “no options” literal is `toOptions {}`.
type OptionsObject = Foreign

-- | Use this function to construct an `OptionsObject`.
toOptions :: forall r. Record r -> OptionsObject
toOptions = unsafeToForeign

-- | Concatenate an `Array` of UTF-8 encoded `Buffer`s into a `String`.
toStringUTF8 :: forall m. MonadEffect m => Array Buffer -> m String
toStringUTF8 bs = liftEffect $ Buffer.toString Encoding.UTF8 =<< Buffer.concat bs

-- | Encode a `String` as an `Array` containing one UTF-8 encoded `Buffer`.
fromStringUTF8 :: forall m. MonadEffect m => String -> Effect (Array Buffer)
fromStringUTF8 s = liftEffect $ map pure $ Buffer.fromString s Encoding.UTF8