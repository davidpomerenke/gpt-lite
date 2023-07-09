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
import Http
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
        { init = \flags -> init flags
        , view = \model -> view model
        , update = \msg model -> update msg model
        , subscriptions = subscriptions
        }



-- MODEL


init : Encode.Value -> ( Model, Cmd Msg )
init flags =
    ( Result.withDefault
        (LoginPage
            { email = ""
            , emailStatus = NotRequested
            }
        )
        (Decode.decodeValue decodePersistedModel flags)
    , Cmd.none
      -- get balance if necessary
      -- get payment link
    )



-- UPDATE


type Msg
    = LoginPageMsg LoginPageMsg
    | MainPageMsg MainPageMsg


type LoginPageMsg
    = EmailAddressTyped String
    | EmailAddressSubmitted
    | EmailAttempted (Result Http.Error Bool)
    | LoginConfirmed ( Bool, UserInfo )


type MainPageMsg
    = ThreadAdded
    | ThreadSelected ThreadId
    | MessageTyped String
    | MessageSubmitted
    | CtrlPressed
    | CtrlReleased
    | EnterPressed
    | ReceivedResponseChunk String
    | ReceivedPaymentLink String
    | UpdatedBalance Float
    | LogoutRequested


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model, msg ) of
        ( LoginPage loginModel, LoginPageMsg loginMsg ) ->
            updateLoginPage loginMsg loginModel

        ( MainPage mainModel, MainPageMsg mainMsg ) ->
            updateMainPage mainMsg mainModel

        _ ->
            ( model, Cmd.none )


updateLoginPage : LoginPageMsg -> LoginPageModel -> ( Model, Cmd Msg )
updateLoginPage msg model =
    case msg of
        EmailAddressTyped email ->
            ( LoginPage { model | email = email }, Cmd.none )

        EmailAddressSubmitted ->
            if isValidEmail model.email then
                ( LoginPage { model | emailStatus = EmailSending }
                , Http.post
                    { url = "http://localhost:3000/request-email"
                    , body = Http.jsonBody (Encode.object [ ( "email", Encode.string model.email ) ])
                    , expect = Http.expectJson (LoginPageMsg << EmailAttempted) Decode.bool
                    }
                )

            else
                ( LoginPage { model | emailStatus = InvalidEmail }, Cmd.none )

        EmailAttempted result ->
            case result of
                Ok True ->
                    ( LoginPage { model | emailStatus = EmailSent }, Cmd.none )

                _ ->
                    ( LoginPage { model | emailStatus = EmailFailed }, Cmd.none )

        -- TODO
        LoginConfirmed ( success, userInfo ) ->
            if success then
                ( MainPage
                    { user = userInfo
                    , messageThreads = Dict.empty
                    , currentThread = 0
                    , messageDraft = ""
                    , ctrlPressed = False
                    , paymentLink = Nothing
                    }
                , Cmd.none
                  -- persistState (encodePersistedModel model.messageThreads newLoginStatus)
                  -- TODO request payment link
                )

            else
                ( LoginPage { model | emailStatus = LoginFailed }, Cmd.none )


updateMainPage : MainPageMsg -> MainPageModel -> ( Model, Cmd Msg )
updateMainPage msg model =
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
                ( MainPage model, Cmd.none )

            else
                ( MainPage
                    { model
                        | messageThreads = Dict.insert threadNumber [] model.messageThreads
                        , currentThread = threadNumber
                    }
                , Cmd.none
                )

        ThreadSelected id ->
            ( MainPage { model | currentThread = id }, Cmd.none )

        MessageTyped newMessage ->
            ( MainPage { model | messageDraft = newMessage }, Cmd.none )

        MessageSubmitted ->
            updateMessageSubmitted oldHistory model

        CtrlPressed ->
            ( MainPage { model | ctrlPressed = True }, Cmd.none )

        CtrlReleased ->
            ( MainPage { model | ctrlPressed = False }, Cmd.none )

        EnterPressed ->
            if model.messageDraft /= "" && model.ctrlPressed then
                updateMessageSubmitted oldHistory model

            else
                ( MainPage model, Cmd.none )

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

                newModel =
                    MainPage { model | messageThreads = newThreads }
            in
            ( newModel
            , outgoingPersistedState (encodePersistedModel newModel)
            )

        ReceivedPaymentLink link ->
            ( MainPage { model | paymentLink = Just link }, Cmd.none )

        UpdatedBalance newBalance ->
            let
                { user } =
                    model
            in
            ( MainPage { model | user = { user | balance = newBalance } }, Cmd.none )

        LogoutRequested ->
            let
                newModel =
                    LoginPage { email = "", emailStatus = NotRequested }
            in
            ( newModel
            , outgoingPersistedState (encodePersistedModel newModel)
            )


updateMessageSubmitted oldHistory model =
    let
        message =
            { role = User, content = model.messageDraft }

        newHistory =
            message :: oldHistory

        newThreads =
            Dict.insert model.currentThread newHistory model.messageThreads

        newModel =
            MainPage
                { model
                    | messageDraft = ""
                    , messageThreads = newThreads
                }
    in
    ( newModel
    , Cmd.batch
        [ chatMessageToBackend (encodeChatMessages (List.reverse newHistory))
        , outgoingPersistedState (encodePersistedModel newModel)
        ]
    )



-- VIEW


view : Model -> Html Msg
view model =
    Element.layout [ Font.size 16 ]
        (case model of
            LoginPage loginModel ->
                Element.map LoginPageMsg (loginPage loginModel)

            MainPage mainModel ->
                Element.map MainPageMsg (mainPage mainModel)
        )


loginPage : LoginPageModel -> Element LoginPageMsg
loginPage model =
    column [ centerX, centerY, spacing 10 ]
        [ Input.email
            ([ Input.focusedOnLoad
             , htmlAttribute (Keyboard.on Keyboard.Keydown [ ( Enter, EmailAddressSubmitted ) ])
             ]
                ++ borderStyle
            )
            { onChange = EmailAddressTyped
            , text = model.email
            , placeholder = Just (Input.placeholder [] (text "Your Email Address"))
            , label =
                Input.labelRight [ spacing 10 ]
                    (Input.button borderStyle
                        { onPress =
                            case model.emailStatus of
                                NotRequested ->
                                    Just EmailAddressSubmitted

                                _ ->
                                    Nothing
                        , label = text "Get Login Link"
                        }
                    )
            }
        , el [ centerX ]
            (case model.emailStatus of
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


mainPage : MainPageModel -> Element MainPageMsg
mainPage model =
    column
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


topBar : MainPageModel -> Element MainPageMsg
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
        [ el [ alignLeft ] (text ("Logged in as " ++ model.user.email))
        , Input.button borderStyle
            { onPress = Just LogoutRequested
            , label = text "Log out"
            }
        , el [ alignRight ] (text ("Balance: " ++ format usLocale model.user.balance))
        , model.paymentLink
            |> Maybe.map (paymentLinkButton model.user.email model.user.id)
            |> Maybe.withDefault none
        ]


paymentLinkButton email user url =
    link [ Background.color (rgb 0 0 0), Font.color (rgb 255 255 255), padding 5 ]
        { url = url ++ "?prefilled_email=" ++ email ++ "&client_reference_id=" ++ user
        , label = text "+ Add funds"
        }


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


threadList : MainPageModel -> List (Element MainPageMsg)
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


messageList : MainPageModel -> List (Element MainPageMsg)
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
        , label = Input.labelRight [] (Input.button borderStyle { onPress = Just MessageSubmitted, label = text "Send" })
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


port chatMessageChunkFromBackend : (String -> msg) -> Sub msg


port chatMessageToBackend : Encode.Value -> Cmd msg


port outgoingPersistedState : Encode.Value -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ chatMessageChunkFromBackend (ReceivedResponseChunk >> MainPageMsg) ]
