module Test.Main where

import Prelude

import Data.Foldable (foldMap)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Options (Options, options, (:=))
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Console (log, logShow)
import Foreign.Object (fromFoldable, lookup)
import Node.Encoding (Encoding(..))
import Node.HTTP (Request, Response, listen, createServer, setHeader, requestHeaders, requestMethod, requestURL, responseAsStream, requestAsStream, setStatusCode, onUpgrade)
import Node.HTTP.Client as Client
import Node.HTTP.Secure as HTTPS
import Node.Net.Socket as Socket
import Node.Stream (Writable, end, pipe, writeString)
import Partial.Unsafe (unsafeCrashWith)
import Test.HTTP2 (testHttp2Client, testHttp2ServerSecure)
import Unsafe.Coerce (unsafeCoerce)

foreign import stdout :: forall r. Writable r

main :: Effect Unit
main = do
  testBasic -- TODO this test prevents node event loop from exiting
  testUpgrade -- TODO this test prevents node event loop from exiting
  testHttpsServer -- TODO this test prevents node event loop from exiting
  testHttps -- TODO this test prevents node event loop from exiting
  testCookies
  testHttp2ServerSecure
  testHttp2Client

respond :: Request -> Response -> Effect Unit
respond req res = do
  setStatusCode res 200
  let inputStream  = requestAsStream req
      outputStream = responseAsStream res
  log (requestMethod req <> " " <> requestURL req)
  case requestMethod req of
    "GET" -> do
      let html = foldMap (_ <> "\n")
            [ "<form method='POST' action='/'>"
            , "  <input name='text' type='text'>"
            , "  <input type='submit'>"
            , "</form>"
            ]
      setHeader res "Content-Type" "text/html"
      _ <- writeString outputStream UTF8 html mempty
      end outputStream (const $ pure unit)
    "POST" -> void $ pipe inputStream outputStream
    _ -> unsafeCrashWith "Unexpected HTTP method"

testBasic :: Effect Unit
testBasic = do
  server <- createServer respond
  listen server { hostname: "localhost", port: 8080, backlog: Nothing } $ void do
    log "Listening on port 8080."
    simpleReq "http://localhost:8080"

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

testHttpsServer :: Effect Unit
testHttpsServer = do
  server <- HTTPS.createServer sslOpts respond
  listen server { hostname: "localhost", port: 8081, backlog: Nothing } $ void do
    log "Listening on port 8081."
    complexReq $
      Client.protocol := "https:" <>
      Client.method := "GET" <>
      Client.hostname := "localhost" <>
      Client.port := 8081 <>
      Client.path := "/" <>
      Client.rejectUnauthorized := false
  where
    sslOpts =
      HTTPS.key := HTTPS.keyString mockKey <>
      HTTPS.cert := HTTPS.certString mockCert

testHttps :: Effect Unit
testHttps =
  simpleReq "https://pursuit.purescript.org/packages/purescript-node-http/badge"

testCookies :: Effect Unit
testCookies =
  simpleReq
    "https://httpbin.org/cookies/set?cookie1=firstcookie&cookie2=secondcookie"

simpleReq :: String -> Effect Unit
simpleReq uri = do
  log ("GET " <> uri <> ":")
  req <- Client.requestFromURI uri logResponse
  end (Client.requestAsStream req) (const $ pure unit)

complexReq :: Options Client.RequestOptions -> Effect Unit
complexReq opts = do
  log $ optsR.method <> " " <> optsR.protocol <> "//" <> optsR.hostname <> ":" <> optsR.port <> optsR.path <> ":"
  req <- Client.request opts logResponse
  end (Client.requestAsStream req) (const $ pure unit)
  where
    optsR = unsafeCoerce $ options opts

logResponse :: Client.Response -> Effect Unit
logResponse response = void do
  log "Headers:"
  logShow $ Client.responseHeaders response
  log "Cookies:"
  logShow $ Client.responseCookies response
  log "Response:"
  let responseStream = Client.responseAsStream response
  pipe responseStream stdout

testUpgrade :: Effect Unit
testUpgrade = do
  server <- createServer respond
  onUpgrade server handleUpgrade
  listen server { hostname: "localhost", port: 3000, backlog: Nothing }
    $ void do
        log "Listening on port 3000."
        sendRequests
  where
  handleUpgrade req socket _ = do
    let upgradeHeader = fromMaybe "" $ lookup "upgrade" $ requestHeaders req
    if upgradeHeader == "websocket" then
      void $ Socket.writeString
        socket
        "HTTP/1.1 101 Switching Protocols\r\nContent-Length: 0\r\n\r\n"
        UTF8
        $ pure unit
    else
      void $ Socket.writeString
        socket
        "HTTP/1.1 426 Upgrade Required\r\nContent-Length: 0\r\n\r\n"
        UTF8
        $ pure unit

  sendRequests = do
    -- This tests that the upgrade callback is not called when the request is not an HTTP upgrade
    reqSimple <- Client.request (Client.port := 3000) \response -> do
      if (Client.statusCode response /= 200) then
        unsafeCrashWith "Unexpected response to simple request on `testUpgrade`"
      else
          pure unit
    end (Client.requestAsStream reqSimple) (const $ pure unit)
    {-
      These two requests test that the upgrade callback is called and that it has
      access to the original request and can write to the underlying TCP socket
    -}
    let headers = Client.RequestHeaders $ fromFoldable
                   [ Tuple "Connection" "upgrade"
                   , Tuple "Upgrade" "something"
                   ]
    reqUpgrade <- Client.request
     (Client.port := 3000 <> Client.headers := headers)
     \response -> do
       if (Client.statusCode response /= 426) then
         unsafeCrashWith "Unexpected response to upgrade request on `testUpgrade`"
       else
          pure unit
    end (Client.requestAsStream reqUpgrade) (const $ pure unit)

    let wsHeaders = Client.RequestHeaders $ fromFoldable
                     [ Tuple "Connection" "upgrade"
                     , Tuple "Upgrade" "websocket"
                     ]

    reqWSUpgrade <- Client.request
     (Client.port := 3000 <> Client.headers := wsHeaders)
     \response -> do
       if (Client.statusCode response /= 101) then
         unsafeCrashWith "Unexpected response to websocket upgrade request on `testUpgrade`"
       else
         pure unit
    end (Client.requestAsStream reqWSUpgrade) (const $ pure unit)
    pure unit
