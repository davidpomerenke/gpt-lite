module Types exposing (..)

import Dict exposing (Dict)
import Dict.Extra as Dict
import Json.Decode as Decode
import Json.Encode as Encode
import String



-- TYPES


type Model
    = LoginPage LoginPageModel
    | MainPage MainPageModel


type alias LoginPageModel =
    { email : String
    , emailStatus : EmailStatus
    }


type EmailStatus
    = NotRequested
    | InvalidEmail
    | EmailSending
    | EmailFailed
    | EmailSent
    | LoginFailed


type alias MainPageModel =
    { user : UserInfo
    , messageThreads : Dict ThreadId (List ChatMessage)
    , currentThread : ThreadId
    , messageDraft : String
    , ctrlPressed : Bool
    , paymentLink : Maybe String
    }


type alias UserInfo =
    { email : String
    , id : String
    , code : String
    , balance : Float
    }


type alias ChatMessage =
    { role : Role
    , content : String
    }


type Role
    = System
    | User
    | Assistant


type alias ThreadId =
    Int



-- ENCODERS


encodePersistedModel : Model -> Encode.Value
encodePersistedModel model =
    case model of
        LoginPage _ ->
            Encode.object
                [ ( "status", Encode.string "logged-out" )
                ]

        MainPage mainModel ->
            Encode.object
                [ ( "status", Encode.string "logged-in" )
                , ( "user", encodeUser mainModel.user )
                , ( "messageThreads", encodeMessageThreads mainModel.messageThreads )
                , ( "currentThread", Encode.int mainModel.currentThread )
                ]


encodeUser : UserInfo -> Encode.Value
encodeUser user =
    Encode.object
        [ ( "email", Encode.string user.email )
        , ( "id", Encode.string user.id )
        , ( "code", Encode.string user.code )
        , ( "balance", Encode.float user.balance )
        ]


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



-- DECODERS


decodePersistedModel : Decode.Decoder Model
decodePersistedModel =
    Decode.field "status" Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "logged-out" ->
                        Decode.succeed (LoginPage { email = "", emailStatus = NotRequested })

                    "logged-in" ->
                        Decode.map3
                            (\user messageThreads currentThread ->
                                MainPage
                                    { user = user
                                    , messageThreads = messageThreads
                                    , currentThread = currentThread
                                    , messageDraft = ""
                                    , ctrlPressed = False
                                    , paymentLink = Nothing
                                    }
                            )
                            (Decode.field "user" decodeUser)
                            (Decode.field "messageThreads" decodeMessageThreads)
                            (Decode.field "currentThread" Decode.int)

                    _ ->
                        Decode.fail "Invalid status"
            )


decodeUser : Decode.Decoder UserInfo
decodeUser =
    Decode.map4 UserInfo
        (Decode.field "email" Decode.string)
        (Decode.field "id" Decode.string)
        (Decode.field "code" Decode.string)
        (Decode.field "balance" Decode.float)


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
