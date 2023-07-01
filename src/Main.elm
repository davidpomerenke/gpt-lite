port module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (property)
import Json.Encode as Encode
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard
import List
import List.Extra as List
import Markdown
import Platform.Cmd as Cmd
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
    { messageThreads : Dict ThreadId (List ChatMessage)
    , currentThread : ThreadId
    , messageDraft : String
    }


init : Model
init =
    { messageThreads = Dict.fromList [ ( 0, [] ) ]
    , currentThread = 0
    , messageDraft = ""
    }


type Msg
    = ThreadAdded
    | ThreadSelected ThreadId
    | MessageTyped String
    | MessageSent
    | ReceivedResponseChunk String



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        oldHistory =
            Dict.get model.currentThread model.messageThreads |> Maybe.withDefault []
    in
    case msg of
        ThreadAdded ->
            let
                threadNumber =
                    (Dict.keys model.messageThreads |> List.maximum |> Maybe.withDefault 0) + 1
            in
            ( { model
                | messageThreads = Dict.insert threadNumber [] model.messageThreads
                , currentThread = threadNumber
              }
            , Cmd.none
            )

        ThreadSelected id ->
            ( { model | currentThread = id }, Cmd.none )

        MessageTyped newMessage ->
            ( { model | messageDraft = newMessage }, Cmd.none )

        MessageSent ->
            if model.messageDraft /= "" then
                let
                    message =
                        { role = User, content = model.messageDraft }

                    newHistory =
                        message :: oldHistory

                    newThreads =
                        Dict.insert model.currentThread newHistory model.messageThreads
                in
                ( { model
                    | messageDraft = ""
                    , messageThreads = newThreads
                  }
                , outgoingMessage (encodeChatMessages (List.reverse newHistory))
                )

            else
                ( model, Cmd.none )

        ReceivedResponseChunk chunk ->
            let
                newHistory =
                    case oldHistory of
                        lastMessage :: rest ->
                            if lastMessage.role == Assistant then
                                { lastMessage | content = lastMessage.content ++ chunk } :: rest

                            else
                                { role = Assistant, content = chunk } :: oldHistory

                        [] ->
                            [ { role = Assistant, content = chunk } ]

                newThreads =
                    Dict.insert model.currentThread newHistory model.messageThreads
            in
            ( { model | messageThreads = newThreads }, Cmd.none )



-- VIEW


mainColor =
    Element.rgba255 0 0 100 0.5


borderStyle =
    [ Border.solid
    , Border.color (rgb 0 0 0)
    , Border.width 2
    , padding 5

    -- , height (shrink |> minimum 30)
    ]


minButtonHeight =
    20


view : Model -> Element Msg
view model =
    row [ width fill, height fill, spacing 50, centerX, Font.size 16 ]
        [ column [ width (fill |> maximum 200), spacing 5, alignTop ]
            (Input.button
                ([ width fill ] ++ borderStyle)
                { onPress = Just ThreadAdded
                , label = text "+ New thread"
                }
                :: (model.messageThreads
                        |> Dict.toList
                        |> List.sortBy (\( threadId, _ ) -> threadId)
                        |> List.reverse
                        |> List.map
                            (\( threadId, threadContent ) ->
                                Input.button
                                    ([ width fill
                                     , Background.color
                                        (if threadId == model.currentThread then
                                            rgb 0 0 0

                                         else
                                            rgb 1 1 1
                                        )
                                     , Font.color
                                        (if threadId == model.currentThread then
                                            rgb 1 1 1

                                         else
                                            rgb 0 0 0
                                        )
                                     ]
                                        ++ borderStyle
                                    )
                                    { onPress = Just (ThreadSelected threadId)
                                    , label =
                                        text
                                            (case List.last threadContent of
                                                Just firstMessage ->
                                                    (String.left 20 firstMessage.content |> String.trim) ++ " ..."

                                                Nothing ->
                                                    "Empty Thread " ++ String.fromInt threadId
                                            )
                                    }
                            )
                   )
            )
        , column [ width (fill |> maximum 800), height fill, spacing 10 ]
            [ column [ width fill, height fill, spacing 10 ]
                (List.map
                    (\message ->
                        el
                            ([ Border.rounded 4
                             , spacing 5
                             , width (shrink |> maximum 600)
                             , htmlAttribute (property "className" (Encode.string "bubble"))
                             , case message.role of
                                User ->
                                    alignRight

                                _ ->
                                    alignLeft
                             ]
                                ++ borderStyle
                            )
                            (html
                                (Markdown.toHtmlWith
                                    { githubFlavored = Just { tables = True, breaks = True }
                                    , defaultHighlighting = Just "python"
                                    , sanitize = True
                                    , smartypants = True
                                    }
                                    []
                                    message.content
                                )
                            )
                    )
                    (List.reverse (Dict.get model.currentThread model.messageThreads |> Maybe.withDefault []))
                )
            , Input.text ([ htmlAttribute (Keyboard.on Keyboard.Keydown [ ( Enter, MessageSent ) ]) ] ++ borderStyle)
                { onChange = MessageTyped
                , text = model.messageDraft
                , placeholder = Nothing
                , label = Input.labelLeft [] none
                }
            ]
        ]



-- PORTS


port incomingMessage : (String -> msg) -> Sub msg


port outgoingMessage : Encode.Value -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    incomingMessage ReceivedResponseChunk
