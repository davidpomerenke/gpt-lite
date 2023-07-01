module Types exposing (..)

import Json.Encode as Encode
import Time exposing (Posix)



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


encodeChatMessage : ChatMessage -> Encode.Value
encodeChatMessage message =
    Encode.object
        [ ( "role", encodeRole message.role )
        , ( "content", Encode.string message.content )
        ]


encodeChatMessages : List ChatMessage -> Encode.Value
encodeChatMessages messages =
    Encode.list encodeChatMessage messages


encodeRole : Role -> Encode.Value
encodeRole role =
    case role of
        System ->
            Encode.string "system"

        User ->
            Encode.string "user"

        Assistant ->
            Encode.string "assistant"
