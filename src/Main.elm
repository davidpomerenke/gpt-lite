module Main exposing (..)

import Browser exposing (Document)
import Browser.Events as BEvents
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Input as Input
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard


type alias Model =
    { messages : List ChatMessage
    , currentMessage : String
    }


type ChatSender
    = Bot
    | User


type alias ChatMessage =
    { sender : ChatSender
    , message : String
    }


init : Model
init =
    { messages = []
    , currentMessage = ""
    }


type Msg
    = Send
    | Update String


update : Msg -> Model -> Model
update msg model =
    case msg of
        Send ->
            if model.currentMessage /= "" then
                { model
                    | messages =
                        model.messages
                            ++ [ { sender = User
                                 , message = model.currentMessage
                                 }
                               , { sender = Bot
                                 , message = "Yes, tell me more!"
                                 }
                               ]
                    , currentMessage = ""
                }

            else
                model

        Update newMessage ->
            { model | currentMessage = newMessage }


view : Model -> Element Msg
view model =
    column [ width (fill |> maximum 600), centerX, height fill ]
        [ column [ width fill, height fill ]
            (List.map
                (\message ->
                    el
                        [ Background.color (Element.rgba255 0 128 0 0.5)
                        , Border.rounded 5
                        , padding 10
                        , if message.sender == Bot then
                            alignLeft

                          else
                            alignRight
                        ]
                        (text message.message)
                )
                model.messages
            )
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
        , update = \msg model -> ( update msg model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }
