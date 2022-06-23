{-
Welcome to a Spago project!
You can edit this file as you like.

Need help? See the following resources:
- Spago documentation: https://github.com/purescript/spago
- Dhall language tour: https://docs.dhall-lang.org/tutorials/Language-Tour.html

When creating a new Spago project, you can use
`spago init --no-comments` or `spago init -C`
to generate this file without the comments in this block.
-}
{ name = "node-http"
, dependencies =
  [ "arraybuffer-types"
  , "console"
  , "contravariant"
  , "effect"
  , "either"
  , "exceptions"
  , "foldable-traversable"
  , "foreign"
  , "foreign-object"
  , "maybe"
  , "node-buffer"
  , "node-net"
  , "node-streams"
  , "node-url"
  , "nullable"
  , "options"
  , "partial"
  , "prelude"
  , "st"
  , "transformers"
  , "tuples"
  , "unsafe-coerce"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
