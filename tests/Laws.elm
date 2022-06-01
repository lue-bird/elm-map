module Laws exposing (..)

import Accessor as A exposing (LensArgument)
import Array exposing (Array)
import Array.Accessor as Array
import Dict exposing (Dict)
import Dict.Accessor as Dict
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, string)
import Lens as L
import List.Accessor as List
import Maybe exposing (Maybe)
import String
import Test exposing (Test, test)


suite : Test
suite =
    Test.describe
        "Laws"
        [ isLens L.name personFuzzer stringAlter string
        , isLens L.age personFuzzer intAlter int
        , isSetable (L.email << A.onJust) personFuzzer stringAlter string

        -- TODO: How to express laws for "Prism"-ish things elm-monocle calls this Optional.
        -- , isOptional (L.email << A.try)
        , isSetable (L.stuff << List.elementAt 0) personFuzzer stringAlter string
        , isSetable (L.stuff << List.elementEach) personFuzzer stringAlter string
        , isSetable (L.things << Array.elementAt 0) personFuzzer stringAlter string
        , isSetable (L.things << Array.elementEach) personFuzzer stringAlter string
        , isLens
            (L.info << Dict.valueAt ( "stuff", identity ))
            personFuzzer
            maybeStringAlter
            (Fuzz.maybe string)
        , test "Name compositions output `jq` style String's" <|
            \() ->
                (L.info << L.stuff << List.elementAt 7 << L.name)
                    |> A.description
                    |> A.descriptionToString
                    |> Expect.equal ".info.stuff(7)?.name"
        ]


type alias Alter a =
    a -> a


stringAlter : Fuzzer (Alter String)
stringAlter =
    Fuzz.oneOf
        -- [ Fuzz.map String.reverse string
        -- , String.toUpper
        -- , String.toLower
        [ Fuzz.map String.append string
        , Fuzz.map (\s -> String.append s >> String.reverse) string
        , Fuzz.map (\s -> String.append s >> String.toUpper) string
        , Fuzz.map (\s -> String.append s >> String.toLower) string
        ]


intAlter : Fuzzer (Alter Int)
intAlter =
    Fuzz.oneOf
        [ Fuzz.map (+) int
        , Fuzz.map (-) int
        , Fuzz.map (*) int
        , Fuzz.map (//) int
        ]


maybeStringAlter : Fuzzer (Alter (Maybe String))
maybeStringAlter =
    Fuzz.oneOf
        [ Fuzz.map
            (\_ ->
                Maybe.andThen String.toInt
                    >> Maybe.map String.fromInt
            )
            (Fuzz.maybe string)
        ]


type alias Person =
    { name : String
    , age : Int
    , email : Maybe String
    , stuff : List String
    , info : Dict String String
    , things : Array String
    }


personFuzzer : Fuzzer Person
personFuzzer =
    Fuzz.constant
        (\name age email stuff info things ->
            { name = name
            , age = age
            , email = email
            , stuff = stuff
            , info = info
            , things = things
            }
        )
        |> Fuzz.andMap string
        |> Fuzz.andMap int
        |> Fuzz.andMap (Fuzz.maybe string)
        |> Fuzz.andMap (Fuzz.list string)
        |> Fuzz.andMap (Fuzz.list (Fuzz.tuple ( string, string )) |> Fuzz.map Dict.fromList)
        |> Fuzz.andMap (Fuzz.list string |> Fuzz.map Array.fromList)


type alias Settable structure transformed attribute built =
    A.Relation attribute attribute built -> A.Relation structure attribute transformed


isSetable :
    Settable structure transformed attribute built
    -> Fuzzer structure
    -> Fuzzer (Alter attribute)
    -> Fuzzer attribute
    -> Test
isSetable l fzr fnFzr val =
    Test.describe
        ("isSetable: " ++ (l |> A.description |> A.descriptionToString))
        [ Test.fuzz fzr
            "identity"
            (Expect.true "setter"
                << setter_id l
            )
        , Test.fuzz
            (Fuzz.tuple3 ( fzr, fnFzr, fnFzr ))
            "composition"
            (\( s, f, g ) ->
                Expect.true "setter" <|
                    setter_composition l s f g
            )
        , Test.fuzz
            (Fuzz.tuple3 ( fzr, val, val ))
            "set_set"
            (\( s, a, b ) ->
                Expect.true "setter" <|
                    setter_set_set l s a b
            )
        ]


isLens :
    LensArgument structure attribute
    -> Fuzzer structure
    -> Fuzzer (Alter attribute)
    -> Fuzzer attribute
    -> Test
isLens l fuzzer valFn val =
    Test.describe
        ("isLens: " ++ (l |> A.description |> A.descriptionToString))
        [ isSetable l fuzzer valFn val

        -- there's Traversal laws in here somewhere but not sure they're expressible in elm
        , Test.fuzz
            fuzzer
            "lens_set_get"
            (lens_set_get l >> Expect.true "lens_set_get")
        , Test.fuzz
            (Fuzz.tuple ( fuzzer, val ))
            "lens_get_set"
            (\( b, s ) ->
                lens_get_set l b s
                    |> Expect.true "lens_get_set"
            )
        ]


setter_id : Settable structure transformed attribute built -> structure -> Bool
setter_id l s =
    A.map l identity s == s


setter_composition :
    Settable structure transformed attribute built
    -> structure
    -> Alter attribute
    -> Alter attribute
    -> Bool
setter_composition l s f g =
    A.map l f (A.map l g s) == A.map l (f << g) s


setter_set_set :
    Settable structure transformed attribute built
    -> structure
    -> attribute
    -> attribute
    -> Bool
setter_set_set l s a b =
    A.map l (\_ -> b) (A.map l (\_ -> a) s) == A.map l (\_ -> b) s


lens_set_get : LensArgument structure attribute -> structure -> Bool
lens_set_get l s =
    A.map l (\_ -> A.access l s) s == s


lens_get_set : LensArgument structure attribute -> structure -> attribute -> Bool
lens_get_set l s a =
    A.access l (A.map l (\_ -> a) s) == a
