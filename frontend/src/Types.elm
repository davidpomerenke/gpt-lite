module Types exposing (..)

import Dict exposing (Dict)
import Dict.Extra as Dict
import Json.Decode as Decode
import Json.Encode as Encode
import String



-- TYPES


type Role
    = System
    | User
    | Assistant


type alias ChatMessage =
    { role : Role
    , content : String
    }


type alias ThreadId =
    Int


type EmailStatus
    = NotRequested
    | InvalidEmail
    | EmailSending
    | EmailFailed
    | EmailSent
    | LoginFailed


type alias UserInfo =
    { email : String
    , user : String
    , code : String
    }


type LoginStatus
    = LoggedOut String EmailStatus
    | LoggedIn UserInfo



-- ENCODERS


encodeMessageThreads : Dict ThreadId (List ChatMessage) -> Encode.Value
encodeMessageThreads threads =
    Encode.object
        (threads
            |> Dict.toList
            |> List.map (\( id, messages ) -> ( String.fromInt id, encodeChatMessages messages ))
        )


encodeChatMessages : List ChatMessage -> Encode.Value
encodeChatMessages messages =
    Encode.list encodeChatMessage messages


encodeChatMessage : ChatMessage -> Encode.Value
encodeChatMessage message =
    Encode.object
        [ ( "role", encodeRole message.role )
        , ( "content", Encode.string message.content )
        ]


encodeRole : Role -> Encode.Value
encodeRole role =
    case role of
        System ->
            Encode.string "system"

        User ->
            Encode.string "user"

        Assistant ->
            Encode.string "assistant"


encodeEmailStatus : EmailStatus -> Encode.Value
encodeEmailStatus status =
    case status of
        NotRequested ->
            Encode.string "not-requested"

        InvalidEmail ->
            Encode.string "invalid-email"

        EmailSending ->
            Encode.string "email-sending"

        EmailFailed ->
            Encode.string "email-failed"

        EmailSent ->
            Encode.string "email-sent"

        LoginFailed ->
            Encode.string "login-failed"


encodeLoginStatus : LoginStatus -> Encode.Value
encodeLoginStatus status =
    case status of
        LoggedOut email emailStatus ->
            Encode.object
                [ ( "status", Encode.string "logged-out" )
                , ( "email", Encode.string email )
                , ( "emailStatus", encodeEmailStatus emailStatus )
                ]

        LoggedIn userInfo ->
            Encode.object
                [ ( "status", Encode.string "logged-in" )
                , ( "email", Encode.string userInfo.email )
                , ( "user", Encode.string userInfo.user )
                , ( "code", Encode.string userInfo.code )
                ]


encodePersistedModel : Dict ThreadId (List ChatMessage) -> LoginStatus -> Encode.Value
encodePersistedModel messageThreads loginStatus =
    Encode.object
        [ ( "messageThreads", encodeMessageThreads messageThreads )
        , ( "loginStatus", encodeLoginStatus loginStatus )
        ]



-- DECODERS


decodeMessageThreads : Decode.Decoder (Dict ThreadId (List ChatMessage))
decodeMessageThreads =
    Decode.dict decodeChatMessages |> Decode.map (Dict.mapKeys (String.toInt >> Maybe.withDefault 0))


decodeChatMessages : Decode.Decoder (List ChatMessage)
decodeChatMessages =
    Decode.list decodeChatMessage


decodeChatMessage : Decode.Decoder ChatMessage
decodeChatMessage =
    Decode.map2 ChatMessage
        (Decode.field "role" decodeRole)
        (Decode.field "content" Decode.string)


decodeRole : Decode.Decoder Role
decodeRole =
    Decode.string
        |> Decode.andThen
            (\role ->
                case role of
                    "system" ->
                        Decode.succeed System

                    "user" ->
                        Decode.succeed User

                    "assistant" ->
                        Decode.succeed Assistant

                    _ ->
                        Decode.fail "Invalid role"
            )


decodeEmailStatus : Decode.Decoder EmailStatus
decodeEmailStatus =
    Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "not-requested" ->
                        Decode.succeed NotRequested

                    "invalid-email" ->
                        Decode.succeed InvalidEmail

                    "email-sending" ->
                        Decode.succeed EmailSending

                    "email-failed" ->
                        Decode.succeed EmailFailed

                    "email-sent" ->
                        Decode.succeed EmailSent

                    "login-failed" ->
                        Decode.succeed LoginFailed

                    _ ->
                        Decode.fail "Invalid email status"
            )


decodeUserInfo : Decode.Decoder UserInfo
decodeUserInfo =
    Decode.map3 UserInfo
        (Decode.field "email" Decode.string)
        (Decode.field "user" Decode.string)
        (Decode.field "code" Decode.string)


decodeLoginStatus : Decode.Decoder LoginStatus
decodeLoginStatus =
    Decode.field "status" Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "logged-out" ->
                        Decode.map2 LoggedOut
                            (Decode.field "email" Decode.string)
                            (Decode.field "emailStatus" decodeEmailStatus)

                    "logged-in" ->
                        Decode.map LoggedIn decodeUserInfo

                    _ ->
                        Decode.fail "Invalid login status"
            )


decodePersistedModel : Decode.Decoder { messageThreads : Dict ThreadId (List ChatMessage), loginStatus : LoginStatus }
decodePersistedModel =
    Decode.map2
        (\messageThreads loginStatus -> { messageThreads = messageThreads, loginStatus = loginStatus })
        (Decode.field "messageThreads" decodeMessageThreads)
        (Decode.field "loginStatus" decodeLoginStatus)
