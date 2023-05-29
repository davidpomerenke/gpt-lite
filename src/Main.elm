port module Main exposing (..)

import Browser exposing (Document)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Json.Decode as Decode
import Json.Encode as Encode
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard
import List


type alias Model =
    { messages : List ChatMessage
    , currentMessage : String
    , error : Maybe String
    }


init : Model
init =
    { messages = []
    , currentMessage = ""
    , error = Nothing
    }


type Msg
    = Send
    | Update String
    | GotResponseChunk String


type Role
    = System
    | User
    | Assistant


type alias ChatMessage =
    { role : Role
    , content : String
    }


encodeRole : Role -> Encode.Value
encodeRole role =
    case role of
        System ->
            Encode.string "system"

        User ->
            Encode.string "user"

        Assistant ->
            Encode.string "assistant"


encodeChatMessage : ChatMessage -> Encode.Value
encodeChatMessage message =
    Encode.object
        [ ( "role", encodeRole message.role )
        , ( "content", Encode.string message.content )
        ]


encodeChatMessages : List ChatMessage -> Encode.Value
encodeChatMessages messages =
    Encode.list encodeChatMessage messages


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Send ->
            if model.currentMessage /= "" then
                let
                    newMessages =
                        { role = User, content = model.currentMessage } :: model.messages
                in
                ( { model
                    | currentMessage = ""
                    , messages = newMessages
                  }
                , outgoingMessage (encodeChatMessages (List.reverse newMessages))
                )

            else
                ( model, Cmd.none )

        Update newMessage ->
            ( { model | currentMessage = newMessage }, Cmd.none )

        GotResponseChunk chunk ->
            let
                messages =
                    case model.messages of
                        lastMessage :: rest ->
                            if lastMessage.role == Assistant then
                                { lastMessage | content = lastMessage.content ++ chunk } :: rest

                            else
                                { role = Assistant, content = chunk } :: model.messages

                        [] ->
                            [ { role = Assistant, content = chunk } ]
            in
            ( { model | messages = messages }, Cmd.none )



-- Err httpError ->
--     ( { model
--         | error = Just <| Debug.toString httpError
--       }
--     , Cmd.none
--     )


view : Model -> Element Msg
view model =
    column [ width (fill |> maximum 600), centerX, height fill, spacing 10 ]
        [ column [ width fill, height fill, spacing 10 ]
            (List.map
                (\message ->
                    paragraph
                        [ Background.color (Element.rgba255 0 128 0 0.5)
                        , Border.rounded 5
                        , padding 5
                        , width (shrink |> maximum 400)
                        , case message.role of
                            User ->
                                alignRight

                            _ ->
                                alignLeft
                        ]
                        [ text message.content ]
                )
                (List.reverse model.messages)
            )
        , if model.error /= Nothing then
            el
                [ Background.color (Element.rgba255 255 0 0 0.5)
                , Border.rounded 5
                , padding 10
                , centerX
                ]
                (text (Maybe.withDefault "" model.error))

          else
            none
        , Input.text [ htmlAttribute (Keyboard.on Keyboard.Keydown [ ( Enter, Send ) ]) ]
            { onChange = Update
            , text = model.currentMessage
            , placeholder = Nothing
            , label = Input.labelLeft [] (text "")
            }
        ]


port incomingMessage : (String -> msg) -> Sub msg


port outgoingMessage : Encode.Value -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    incomingMessage GotResponseChunk


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( init, Cmd.none )
        , view = \model -> Element.layout [ padding 10 ] (view model)
        , update = \msg model -> update msg model
        , subscriptions = subscriptions
        }
