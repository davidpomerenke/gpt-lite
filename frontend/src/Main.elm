port module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Html exposing (Html)
import Html.Attributes exposing (property)
import Json.Decode as Decode
import Json.Encode as Encode
import Keyboard exposing (Key(..))
import Keyboard.Events as Keyboard
import List
import List.Extra as List
import Markdown
import Platform.Cmd as Cmd
import Types exposing (..)


main : Program Encode.Value Model Msg
main =
    Browser.element
        { init = \flags -> ( init flags, Cmd.none )
        , view = \model -> view model
        , update = \msg model -> update msg model
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { messageThreads : Dict ThreadId (List ChatMessage)
    , currentThread : ThreadId
    , messageDraft : String
    , ctrlPressed : Bool
    , balance : Float
    , paymentLink : Maybe String
    }


init : Encode.Value -> Model
init flags =
    { messageThreads = Decode.decodeValue decodeMessageThreads flags |> Result.withDefault Dict.empty
    , currentThread = 0
    , messageDraft = ""
    , ctrlPressed = False
    , balance = 0.0
    , paymentLink = Nothing
    }


type Msg
    = ThreadAdded
    | ThreadSelected ThreadId
    | MessageTyped String
    | CtrlPressed
    | CtrlReleased
    | EnterPressed
    | ReceivedResponseChunk String
    | ReceivedPaymentLink String
    | UpdatedBalance Float



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
            if List.isEmpty oldHistory then
                ( model, Cmd.none )

            else
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

        CtrlPressed ->
            ( { model | ctrlPressed = True }, Cmd.none )

        CtrlReleased ->
            ( { model | ctrlPressed = False }, Cmd.none )

        EnterPressed ->
            if model.messageDraft /= "" && model.ctrlPressed then
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
                , Cmd.batch
                    [ outgoingMessage (encodeChatMessages (List.reverse newHistory))
                    , persistState (encodeMessageThreads newThreads)
                    ]
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
            ( { model | messageThreads = newThreads }, persistState (encodeMessageThreads newThreads) )

        ReceivedPaymentLink link ->
            ( { model | paymentLink = Just link }, Cmd.none )

        UpdatedBalance newBalance ->
            ( { model | balance = newBalance }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    Element.layout [ Font.size 16 ]
        (column
            [ height fill, width fill, spacing 10 ]
            [ topBar model
            , row [ height fill, width fill, centerX, padding 10, spacing 50 ]
                [ column [ width (fill |> maximum 200), spacing 5, alignTop ] (newThreadButton model :: threadList model)
                , column [ width (fill |> maximum 800), height fill, spacing 10 ]
                    [ column [ width fill, height fill, spacing 10 ] (messageList model)
                    , promptInput model
                    ]
                ]
            ]
        )


topBar : Model -> Element Msg
topBar model =
    row
        [ height shrink
        , width fill
        , Border.solid
        , Border.color (rgb 0 0 0)
        , Border.widthEach { top = 0, right = 0, bottom = 2, left = 0 }
        , padding 5
        , spacing 10
        ]
        [ el [ alignRight ] (text ("Balance: " ++ format usLocale model.balance))
        , model.paymentLink |> Maybe.map paymentLinkButton |> Maybe.withDefault none
        ]


paymentLinkButton : String -> Element Msg
paymentLinkButton a =
    link [ Background.color (rgb 0 0 0), Font.color (rgb 255 255 255), padding 5 ]
        { url = a
        , label = text "+ Add funds"
        }


newThreadButton : Model -> Element Msg
newThreadButton model =
    Input.button
        (width fill
            :: borderStyle
            ++ (if
                    Dict.get model.currentThread model.messageThreads
                        |> Maybe.map List.isEmpty
                        |> Maybe.withDefault True
                then
                    inverseColors

                else
                    colors
               )
        )
        { onPress = Just ThreadAdded
        , label = text "+ New thread"
        }


threadList : Model -> List (Element Msg)
threadList model =
    model.messageThreads
        |> Dict.toList
        |> List.sortBy (\( threadId, _ ) -> threadId)
        |> List.reverse
        |> List.map
            (\( threadId, threadContent ) ->
                case List.last threadContent of
                    Just firstMessage ->
                        Input.button
                            (width fill
                                :: borderStyle
                                ++ (if threadId == model.currentThread then
                                        inverseColors

                                    else
                                        colors
                                   )
                            )
                            { onPress = Just (ThreadSelected threadId)
                            , label =
                                text
                                    ((String.left 20 firstMessage.content |> String.trim)
                                        ++ (if String.length firstMessage.content > 20 then
                                                " ..."

                                            else
                                                ""
                                           )
                                    )
                            }

                    Nothing ->
                        none
            )


messageList : Model -> List (Element Msg)
messageList model =
    List.map
        (\message ->
            row
                [ width fill, spacing 10 ]
                [ case message.role of
                    User ->
                        el [ width (fillPortion 1) ] none

                    _ ->
                        none
                , row [ width (fillPortion 4) ]
                    [ none
                    , column [ width fill ]
                        [ el
                            ([ Border.rounded 4
                             , spacing 5
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
                                    , defaultHighlighting = Just "markdown"
                                    , sanitize = True
                                    , smartypants = True
                                    }
                                    []
                                    message.content
                                )
                            )
                        ]
                    ]
                , case message.role of
                    User ->
                        none

                    _ ->
                        el [ width (fillPortion 1) ] none
                ]
        )
        (List.reverse (Dict.get model.currentThread model.messageThreads |> Maybe.withDefault []))


promptInput : Model -> Element Msg
promptInput model =
    Input.multiline
        ([ Input.focusedOnLoad
         , htmlAttribute
            (Keyboard.on Keyboard.Keydown
                [ ( Control, CtrlPressed )
                , ( Meta, CtrlPressed )
                , ( Enter, EnterPressed )
                ]
            )
         , htmlAttribute
            (Keyboard.on Keyboard.Keyup
                [ ( Control, CtrlReleased )
                , ( Meta, CtrlReleased )
                ]
            )
         ]
            ++ borderStyle
        )
        { onChange = MessageTyped
        , text = model.messageDraft
        , placeholder = Nothing
        , label = Input.labelRight [] (Input.button borderStyle { onPress = Just EnterPressed, label = text "Send" })
        , spellcheck = False
        }


borderStyle =
    [ Border.solid
    , Border.color (rgb 0 0 0)
    , Border.width 2
    , padding 5
    ]


colors =
    [ Background.color (rgb 1 1 1), Font.color (rgb 0 0 0) ]


inverseColors =
    [ Background.color (rgb 0 0 0), Font.color (rgb 1 1 1) ]



-- PORTS


port incomingMessage : (String -> msg) -> Sub msg


port outgoingMessage : Encode.Value -> Cmd msg


port persistState : Encode.Value -> Cmd msg


port paymentLink : (String -> msg) -> Sub msg


port balanceUpdate : (Float -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ incomingMessage ReceivedResponseChunk
        , paymentLink ReceivedPaymentLink
        , balanceUpdate UpdatedBalance
        ]
