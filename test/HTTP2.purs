module Test.HTTP2 where

import Prelude

import Control.Monad.ST.Class (liftST)
import Control.Monad.ST.Ref as ST.Ref
import Data.Foldable (for_)
import Data.Maybe (fromMaybe, maybe)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff, runAff_)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Node.Encoding as Node.Encoding
import Node.HTTP2 (headerKeys, headerString, toHeaders, toOptions)
import Node.HTTP2.Client as HTTP2.Client
import Node.HTTP2.Client.Aff (close, connect, request) as HTTP2.Client.Aff
import Node.HTTP2.Server as HTTP2.Server
import Node.HTTP2.Server.Aff as HTTP2.Server.Aff
import Node.Stream as Node.Stream
import Node.URL as URL
import Unsafe.Coerce (unsafeCoerce)


testHttp2ServerSecure :: Effect Unit
testHttp2ServerSecure = do

  server <- HTTP2.Server.createSecureServer
    (toOptions {key: mockKey, cert: mockCert})
    logError

  void $ HTTP2.Server.onceStreamSecure server \stream _ _ -> do
    HTTP2.Server.respond stream
      (toHeaders
        { "content-type": "text/html; charset=utf-8"
        , ":status": 200
        }
      )
      (toOptions {})
    void $ Node.Stream.writeString (HTTP2.Server.toDuplex stream)
      Node.Encoding.UTF8
      "HTTP/2 Secure Body"
      \err -> do
        maybe (pure unit) logError err
        Node.Stream.end (HTTP2.Server.toDuplex stream)
          \err2 -> do
            maybe (pure unit) logError err2
            HTTP2.Server.closeServerSecure server (pure unit)

  HTTP2.Server.listenSecure server
    (toOptions { port:8443 })
    (pure unit)

  where
    logError err = Console.log (unsafeCoerce err)

testHttp2Client :: Effect Unit
testHttp2Client = do

  clientsession <- HTTP2.Client.connect
    (URL.parse "https://localhost:8443")
    (toOptions {ca: mockCert})
    (\_ _ -> pure unit)

  clientstream <- HTTP2.Client.request clientsession
    (toHeaders {":path": "/"})
    (toOptions {})

  HTTP2.Client.onceResponse clientstream
    \headers _ ->
      for_ (headerKeys headers) \name ->
        Console.log $
          name <> ": " <> fromMaybe "" (headerString headers name)

  let req = HTTP2.Client.toDuplex clientstream

  dataRef <- liftST $ ST.Ref.new ""
  Node.Stream.onDataString req Node.Encoding.UTF8
    \chunk -> void $ liftST $ ST.Ref.modify (_ <> chunk) dataRef
  Node.Stream.onEnd req do
    dataString <- liftST $ ST.Ref.read dataRef
    Console.log $ "\n" <> dataString
    HTTP2.Client.close clientsession (pure unit)

testHttp2ServerSecureAff :: Aff Unit
testHttp2ServerSecureAff = do

  void $ HTTP2.Server.Aff.listenSecure
    (toOptions {key: mockKey, cert: mockCert})
    (toOptions {port: 8444})
    \server _ stream -> do
      HTTP2.Server.Aff.respond stream
        (toHeaders
          { "content-type": "text/html; charset=utf-8"
          , ":status": 200
          }
        )
      -- There are no separate test dependencies so we can't add
      -- Node.Stream.Aff dependency so we can't do Aff write.
      liftEffect $ void $ Node.Stream.writeString (HTTP2.Server.toDuplex stream)
        Node.Encoding.UTF8
        "HTTP/2 Secure Body Aff"
        \err -> do
          maybe (pure unit) logError err
          Node.Stream.end (HTTP2.Server.toDuplex stream)
            \err2 -> do
              maybe (pure unit) logError err2
      HTTP2.Server.Aff.closeServerSecure server

  where
    logError err = Console.log (unsafeCoerce err)


testHttp2ClientAff :: Aff Unit
testHttp2ClientAff = do

  clientsession <- HTTP2.Client.Aff.connect
    (toOptions {ca: mockCert})
    (URL.parse "https://localhost:8444")

  Tuple headers clientstream <- HTTP2.Client.Aff.request clientsession
    (toOptions {})
    (toHeaders {":path": "/"})

  liftEffect $ for_ (headerKeys headers) \name ->
    Console.log $ name <> ": " <> fromMaybe "" (headerString headers name)

  let req = HTTP2.Client.toDuplex clientstream

  -- There are no separate test dependencies so we can't add
  -- Node.Stream.Aff dependency so we can't do Aff readAll.
  dataRef <- liftEffect $ liftST $ ST.Ref.new ""
  liftEffect $ Node.Stream.onDataString req Node.Encoding.UTF8
    \chunk -> void $ liftST $ ST.Ref.modify (_ <> chunk) dataRef
  liftEffect $ Node.Stream.onEnd req do
    dataString <- liftST $ ST.Ref.read dataRef
    Console.log $ "\n" <> dataString
    runAff_ (\_ -> pure unit) $ HTTP2.Client.Aff.close clientsession


-- https://letsencrypt.org/docs/certificates-for-localhost/#making-and-trusting-your-own-certificates

mockCert :: String
mockCert =
  """-----BEGIN CERTIFICATE-----
MIIDDzCCAfegAwIBAgIUEKTSwDsPYQAJ3LAkrJm8flqrTeMwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTIyMDYzMDEzMzcyNVoXDTIyMDcz
MDEzMzcyNVowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAn7frp/SfThq7/5WL9VFL5eRcUzYYNqHE05caZFxKcL9l
BWjk9IfoSWimwQ3x/KDBwuRJCc+tIZn61Mz6FKlC3m2ALC6jEqBcPODvdtlCPnir
6i6piLoLfd+tbMh/dMgNdgNx2hXWjMRSVLiJg0+sXNu9tP+0j/UDw4xJa1PObjUE
rM/aKpSYwY4SuI3rIUpdMpDjL/dnJnbYVxXNt4UPUBqTqyEwIlAi7xXB79zVFLQL
By0w0NU+nm0XlNv5BD90vNk493yNcHC12Nw/ueSD96loYXx2mQ/P42ePcJ2db+xu
2jj6F8cVRUKBSQtKAfzsSHT/hv88uKLQ6gsYlR5ErwIDAQABo1kwVzAUBgNVHREE
DTALgglsb2NhbGhvc3QwCwYDVR0PBAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMB
MB0GA1UdDgQWBBS9wJ/IdinilpuCyX/NRHIEdcauMjANBgkqhkiG9w0BAQsFAAOC
AQEAleSZEPI6qIcezwB9fTmvT1bf42Tfit9PUczPGkJ9vrktG9TZnwWjdLQx+tcW
9gRPVkyLZo63EaoqqiV9iVpL71YXu7GTihcyWgi6TO6PObbba5BLPZ2m4ITmcwLJ
4Hzf3u7+wNiBZwDtluR3bGrXORK8TXSRKuZixbot1EHFUV+/JBqKsEbI/MtOA7Ht
aPBqklmDY1Y0b/Q+EHA4lfrerGaJnXCM8dn0NhL1/66ICQPOnf6lRbc/ZTyAXNGo
NE9AsyZAKz2eGBVwr9ePKG0tOfBXr4r3029FBR0ctodxyI7IFd+ZwJS6RKFPhgd4
8YPxDzeGkdG1N2W1f/up/NXU1Q==
-----END CERTIFICATE-----"""

mockKey :: String
mockKey =
  """-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCft+un9J9OGrv/
lYv1UUvl5FxTNhg2ocTTlxpkXEpwv2UFaOT0h+hJaKbBDfH8oMHC5EkJz60hmfrU
zPoUqULebYAsLqMSoFw84O922UI+eKvqLqmIugt9361syH90yA12A3HaFdaMxFJU
uImDT6xc2720/7SP9QPDjElrU85uNQSsz9oqlJjBjhK4jeshSl0ykOMv92cmdthX
Fc23hQ9QGpOrITAiUCLvFcHv3NUUtAsHLTDQ1T6ebReU2/kEP3S82Tj3fI1wcLXY
3D+55IP3qWhhfHaZD8/jZ49wnZ1v7G7aOPoXxxVFQoFJC0oB/OxIdP+G/zy4otDq
CxiVHkSvAgMBAAECggEAAdmjELMsOemPCPMQsnr1Gp4jwFEC7yBo7nHfJo93y0jk
S4TqC2Jxpea2RnaPZDeb1v1G/VFFtlBuz+fp87L8PnsH6OXHZ3qqZt13g1Rundj5
q4D2ih9sQlKE00WaowiC42g/JDbBi/2QM0FfUmvqBA9a6g2rkp6qIv9ChcxBkBQ8
yGgOBVli5nd4/GMNfvD3rBznNW4uR1Kt0rqPvdvs/oqfdZKiJPIA0WOiPGSK5Ta5
Sb8lsPBmlYaaG8hViIOCKrUiI1m4TTotY8lFXaq7vGEz3JylJa5S4q3lrnqwfv8u
npKZYKe1Cy4cxcbniStOkSLHzW0yPwu8WQ5ACqyxTQKBgQDZRExfQ8HDBvwIv3Jw
VsRrOIhr4hWA7CQdfuIF5tW12qSFCvpHylRW5fgxQu2i3YTI26OSjw4mfgREB8IS
HTxU82Ft8/yfbgTNWU20h+3bQ/q5SAvtZv/idt8XneNEhUAFGGbR3mfnbirCSW2y
5v4M6W5euHwPWC9LxCduiqK+OwKBgQC8MTWbz+yo7d6aH0/JedRdaGNnn7GNJXyN
Ei92hIfx8iJCfYAVR1qwiG3kS44Jxq8sbgvb8AdwDSArClaphmMOZ2gbyAebL4Cp
2GoEcZtdEnWrgkEDmx0Oado7j2Kf1kSuZ/4ftUTA2KuEXGbM3a0TQ9HDTRRmrWXX
uQyaRgioHQKBgQCFnx2hUVivi3IiJyxIrvRqRQCR6R/0hEbJ5Sk5G/i/uVKJiHDZ
CjTIpPL5yQHBsp9hsMNu9ZBsWABjnqna3iQm0vBO4Umy+8T0TkIeD6NXwP1ISmkb
fsdNDnKyYaZOk+0FtTY3SKN6kCS4DNTsvGfupPn+Q1P5U/DylhbyQ01H1QKBgQCS
9DpQeYTsRRNWdqzvP1s9tY4qFOGovmUMI+88NTGTFOj70tR5yUZgI6jsZLN9ntCb
eTN5g23LafR8p44UwwQG82iwiPqni+iEuKHQ5oXTn96TFxt9nVqLLs1jRQxWlBL9
vecLC5msnYURzrXXtCK6sHLUdxQ/OZgVZEMbFSUdYQKBgAhV1GB5Rm9aih+g+0ye
FTHwFdz14TJJ8wYS8YtVbdJ79seQupdLpmuDOalWWLKrzvJcKGp9RPMotXOniqIO
edV8yFsNq1pkiZpwPyYZkicG6oDKAW9i29OUi/KgxGPl55Nc/wVlJ9euVUZDf9vp
xPvm4gj82zufCKFUdMkdpBj2
-----END PRIVATE KEY-----"""
