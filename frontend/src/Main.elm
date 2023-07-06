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
import Validate exposing (isValidEmail)


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
    , loginStatus : LoginStatus
    }


init : Encode.Value -> Model
init flags =
    let
        messageThreads =
            Decode.decodeValue decodeMessageThreads flags |> Result.withDefault Dict.empty
    in
    { messageThreads = messageThreads
    , currentThread = Dict.keys messageThreads |> List.maximum |> Maybe.withDefault 0
    , messageDraft = ""
    , ctrlPressed = False
    , balance = 0.0
    , paymentLink = Nothing
    , loginStatus = LoggedOut "" NotRequested
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
    | EmailAddressTyped String
    | EmailAddressSubmitted
    | EmailAttempted Bool
    | LoginConfirmed ( Bool, String, String )
    | LogoutRequested



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

        EmailAddressTyped email ->
            ( { model | loginStatus = LoggedOut email NotRequested }, Cmd.none )

        EmailAddressSubmitted ->
            case model.loginStatus of
                LoggedOut email NotRequested ->
                    if isValidEmail email then
                        ( { model | loginStatus = LoggedOut email EmailSending }, submitEmailAddress email )

                    else
                        ( { model | loginStatus = LoggedOut email InvalidEmail }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        EmailAttempted success ->
            case ( model.loginStatus, success ) of
                ( LoggedOut email _, True ) ->
                    ( { model | loginStatus = LoggedOut email EmailSent }, Cmd.none )

                ( LoggedOut email _, False ) ->
                    ( { model | loginStatus = LoggedOut email EmailFailed }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        LoginConfirmed ( success, email, code ) ->
            if success then
                ( { model | loginStatus = LoggedIn email code }, Cmd.none )

            else
                ( { model | loginStatus = LoggedOut email EmailFailed }, Cmd.none )

        LogoutRequested ->
            ( { model | loginStatus = LoggedOut "" NotRequested }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    Element.layout [ Font.size 16 ]
        (case model.loginStatus of
            LoggedOut email emailSent ->
                loginPage model email emailSent

            LoggedIn email code ->
                mainPage model email code
        )


loginPage model email emailSent =
    column [ centerX, centerY, spacing 10 ]
        [ Input.email (Input.focusedOnLoad :: borderStyle)
            { onChange = EmailAddressTyped
            , text = email
            , placeholder = Just (Input.placeholder [] (text "Your Email Address"))
            , label =
                Input.labelRight [ spacing 10 ]
                    (Input.button borderStyle
                        { onPress =
                            case emailSent of
                                NotRequested ->
                                    Just EmailAddressSubmitted

                                _ ->
                                    Nothing
                        , label = text "Get Login Link"
                        }
                    )
            }
        , el [ centerX ]
            (case emailSent of
                NotRequested ->
                    Element.none

                InvalidEmail ->
                    text "Invalid email address."

                EmailSending ->
                    text "Sending login link ..."

                EmailFailed ->
                    text "Failed to send login link to this email address. Maybe try again?"

                EmailSent ->
                    text "A login link has been sent to your email address."

                LoginFailed ->
                    text "Your login link has expired. Please try again."
            )
        ]


mainPage : Model -> String -> String -> Element Msg
mainPage model email code =
    column
        [ height fill, width fill, spacing 10 ]
        [ topBar model email
        , row [ height fill, width fill, centerX, padding 10, spacing 50 ]
            [ column [ width (fill |> maximum 200), spacing 5, alignTop ] (newThreadButton model :: threadList model)
            , column [ width (fill |> maximum 800), height fill, spacing 10 ]
                [ column [ width fill, height fill, spacing 10 ] (messageList model)
                , promptInput model
                ]
            ]
        ]


topBar : Model -> String -> Element Msg
topBar model email =
    row
        [ height shrink
        , width fill
        , Border.solid
        , Border.color (rgb 0 0 0)
        , Border.widthEach { top = 0, right = 0, bottom = 2, left = 0 }
        , padding 5
        , spacing 10
        ]
        [ el [ alignLeft ] (text ("Logged in as " ++ email))
        , Input.button borderStyle
            { onPress = Just LogoutRequested
            , label = text "Log out"
            }
        , el [ alignRight ] (text ("Balance: " ++ format usLocale model.balance))
        , model.paymentLink |> Maybe.map (paymentLinkButton email) |> Maybe.withDefault none
        ]


paymentLinkButton : String -> String -> Element Msg
paymentLinkButton email a =
    link [ Background.color (rgb 0 0 0), Font.color (rgb 255 255 255), padding 5 ]
        { url = a ++ "?prefilled_email=" ++ email
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


port submitEmailAddress : String -> Cmd msg


port confirmEmailSent : (Bool -> msg) -> Sub msg


port login : (( Bool, String, String ) -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ incomingMessage ReceivedResponseChunk
        , paymentLink ReceivedPaymentLink
        , balanceUpdate UpdatedBalance
        , confirmEmailSent EmailAttempted
        , login LoginConfirmed
        ]
