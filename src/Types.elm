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
