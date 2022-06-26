-- | Low-level bindings to the *Node.js* [HTTP/2](https://nodejs.org/docs/latest/api/http2.html) API.
module Node.HTTP2
  ( Headers
  , toHeaders
  , headerKeys
  , headerValueString
  , headerValueArray
  , headerStatus
  , OptionsObject
  , toOptions
  , Flags
  )
  where

import Prelude

import Control.Monad.Except (runExcept)
import Data.Either (hush)
import Data.Maybe (Maybe)
import Data.Traversable (traverse)
import Foreign (Foreign, readArray, readInt, readString, unsafeToForeign)
import Foreign.Index (readProp)
import Foreign.Object (Object, keys)
import Unsafe.Coerce (unsafeCoerce)

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
headerValueString :: Headers -> String -> Maybe String
headerValueString h n = hush $ runExcept do
  readString =<< readProp n (unsafeCoerce h)

-- | Try to read an `Array String` value from the `Headers` at the given key.
headerValueArray :: Headers -> String -> Maybe (Array String)
headerValueArray h n = hush $ runExcept do
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
