module Main exposing (..)

import Browser exposing (Document)
import Browser.Events as BEvents
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Input as Input
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard


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
    | GotResponse (Result Http.Error String)


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
                        model.messages ++ [ { role = User, content = model.currentMessage } ]

                    cmd =
                        Http.post
                            { url = "http://localhost:3001/chat"
                            , body = Http.jsonBody (encodeChatMessages newMessages)
                            , expect = Http.expectJson GotResponse <| Decode.field "reply" Decode.string
                            }
                in
                ( { model
                    | currentMessage = ""
                    , messages = newMessages
                    , error = Nothing
                  }
                , cmd
                )

            else
                ( model, Cmd.none )

        Update newMessage ->
            ( { model | currentMessage = newMessage }, Cmd.none )

        GotResponse result ->
            case result of
                Ok reply ->
                    ( { model
                        | messages = model.messages ++ [ { role = Assistant, content = reply } ]
                        , error = Nothing
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( { model
                        | error = Just <| Debug.toString httpError
                      }
                    , Cmd.none
                    )


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
                model.messages
            )
        , if model.error /= Nothing then
            el
                [ Background.color (Element.rgba255 255 0 0 0.5)
                , Border.rounded 5
                , padding 10
                , centerX
                ]
                (text <| Maybe.withDefault "" model.error)

          else
            none
        , Input.text [ htmlAttribute (Keyboard.on Keyboard.Keydown [ ( Enter, Send ) ]) ]
            { onChange = Update
            , text = model.currentMessage
            , placeholder = Nothing
            , label = Input.labelLeft [] (text "")
            }
        ]


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> ( init, Cmd.none )
        , view =
            \model ->
                { title = "GPT++"
                , body = [ Element.layout [ padding 10 ] (view model) ]
                }
        , update = \msg model -> update msg model
        , subscriptions = \_ -> Sub.none
        }
