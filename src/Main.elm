port module Main exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Json.Encode as Encode
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard
import List
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( init, Cmd.none )
        , view = \model -> Element.layout [ padding 10 ] (view model)
        , update = \msg model -> update msg model
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { messageHistory : List ChatMessage
    , messageDraft : String
    , error : Maybe String
    }


init : Model
init =
    { messageHistory = []
    , messageDraft = ""
    , error = Nothing
    }


type Msg
    = MessageSent
    | MessageTyped String
    | ReceivedResponseChunk String



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MessageSent ->
            if model.messageDraft /= "" then
                let
                    newMessages =
                        { role = User, content = model.messageDraft } :: model.messageHistory
                in
                ( { model
                    | messageDraft = ""
                    , messageHistory = newMessages
                  }
                , outgoingMessage (encodeChatMessages (List.reverse newMessages))
                )

            else
                ( model, Cmd.none )

        MessageTyped newMessage ->
            ( { model | messageDraft = newMessage }, Cmd.none )

        ReceivedResponseChunk chunk ->
            let
                messages =
                    case model.messageHistory of
                        lastMessage :: rest ->
                            if lastMessage.role == Assistant then
                                { lastMessage | content = lastMessage.content ++ chunk } :: rest

                            else
                                { role = Assistant, content = chunk } :: model.messageHistory

                        [] ->
                            [ { role = Assistant, content = chunk } ]
            in
            ( { model | messageHistory = messages }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    column [ width (fill |> maximum 800), centerX, height fill, spacing 10 ]
        [ column [ width fill, height fill, spacing 10 ]
            (List.map
                (\message ->
                    column
                        [ Background.color (Element.rgba255 0 128 0 0.5)
                        , Border.rounded 5
                        , padding 5
                        , spacing 5
                        , Font.size 16
                        , width (shrink |> maximum 600)
                        , case message.role of
                            User ->
                                alignRight

                            _ ->
                                alignLeft
                        ]
                        (String.split "\n" message.content |> List.map (\a -> paragraph [] [ text a ]))
                )
                (List.reverse model.messageHistory)
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
        , Input.text [ htmlAttribute (Keyboard.on Keyboard.Keydown [ ( Enter, MessageSent ) ]) ]
            { onChange = MessageTyped
            , text = model.messageDraft
            , placeholder = Nothing
            , label = Input.labelLeft [] none
            }
        ]



-- PORTS


port incomingMessage : (String -> msg) -> Sub msg


port outgoingMessage : Encode.Value -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    incomingMessage ReceivedResponseChunk
