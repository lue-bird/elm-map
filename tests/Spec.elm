module Spec exposing (suite)

import Accessor exposing (Relation, access, map, overLazy)
import Dict exposing (Dict)
import Expect
import Lens as L
import List.Accessor as List
import Test exposing (Test, test)


simpleRecord : { foo : number, bar : String, qux : Bool }
simpleRecord =
    { foo = 3, bar = "Yop", qux = False }


anotherRecord : { foo : number, bar : String, qux : Bool }
anotherRecord =
    { foo = 5, bar = "Sup", qux = True }


nestedRecord : { foo : { foo : number, bar : String, qux : Bool } }
nestedRecord =
    { foo = simpleRecord }


recordWithList : { bar : List { foo : number, bar : String, qux : Bool } }
recordWithList =
    { bar = [ simpleRecord, anotherRecord ] }


maybeRecord : { bar : Maybe { foo : number, bar : String, qux : Bool }, foo : Maybe a }
maybeRecord =
    { bar = Just simpleRecord, foo = Nothing }


dict : Dict String number
dict =
    Dict.fromList [ ( "foo", 7 ) ]


recordWithDict : { bar : Dict String number }
recordWithDict =
    { bar = dict }


dictWithRecord : Dict String { bar : String }
dictWithRecord =
    Dict.fromList [ ( "foo", { bar = "Yop" } ) ]


suite : Test
suite =
    Test.describe
        "strict lenses"
        [ Test.describe
            "access"
            [ test "simple" <|
                \_ ->
                    simpleRecord
                        |> access L.foo
                        |> Expect.equal 3
            , test "nested" <|
                \_ ->
                    nestedRecord
                        |> access (L.foo << L.bar)
                        |> Expect.equal "Yop"
            , test "in list" <|
                \_ ->
                    recordWithList
                        |> access (L.bar << List.elementEach << L.foo)
                        |> Expect.equal [ 3, 5 ]
            , test "in Just" <|
                \_ ->
                    maybeRecord
                        |> access (L.bar << onJust << L.qux)
                        |> Expect.equal (Just False)
            , test "in Nothing" <|
                \_ ->
                    maybeRecord
                        |> access (L.foo << onJust << L.bar)
                        |> Expect.equal Nothing
            , Test.describe
                "dict"
                [ test "present" <|
                    \_ ->
                        dict
                            |> access (key "foo")
                            |> Expect.equal (Just 7)
                , test "absent" <|
                    \_ ->
                        dict
                            |> access (key "bar")
                            |> Expect.equal Nothing
                , test "nested present" <|
                    \_ ->
                        recordWithDict
                            |> access (L.bar << key "foo")
                            |> Expect.equal (Just 7)
                , test "nested absent" <|
                    \_ ->
                        recordWithDict
                            |> access (L.bar << key "bar")
                            |> Expect.equal Nothing
                , test "with try" <|
                    \_ ->
                        dictWithRecord
                            |> access (key "foo" << onJust << L.bar)
                            |> Expect.equal (Just "Yop")
                , test "with def" <|
                    \_ ->
                        dictWithRecord
                            |> access (key "not_it" << def { bar = "Stuff" } << L.bar)
                            |> Expect.equal "Stuff"
                , test "with or" <|
                    \_ ->
                        dictWithRecord
                            |> access ((key "not_it" << onJust << L.bar) |> or "Stuff")
                            |> Expect.equal "Stuff"
                ]
            ]
        , Test.describe
            "map (\\_ -> ...)"
            [ test "simple" <|
                \_ ->
                    let
                        updatedExample : { foo : number, bar : String, qux : Bool }
                        updatedExample =
                            simpleRecord |> map L.qux (\_ -> True)
                    in
                    updatedExample.qux
                        |> Expect.equal True
            , test "nested" <|
                \_ ->
                    let
                        updatedExample : { foo : { foo : number, bar : String, qux : Bool } }
                        updatedExample =
                            nestedRecord |> map (L.foo << L.foo) (\_ -> 5)
                    in
                    updatedExample.foo.foo
                        |> Expect.equal 5
            , test "in list" <|
                \_ ->
                    let
                        updatedExample : { bar : List { foo : number, bar : String, qux : Bool } }
                        updatedExample =
                            recordWithList |> map (L.bar << List.elementEach << L.bar) (\_ -> "Why, hello")
                    in
                    updatedExample
                        |> access (L.bar << List.elementEach << L.bar)
                        |> Expect.equal [ "Why, hello", "Why, hello" ]
            , test "in Just" <|
                \_ ->
                    let
                        updatedExample : { bar : Maybe { foo : number, bar : String, qux : Bool }, foo : Maybe a }
                        updatedExample =
                            maybeRecord |> map (L.bar << onJust << L.foo) (\_ -> 4)
                    in
                    updatedExample
                        |> access (L.bar << onJust << L.foo)
                        |> Expect.equal (Just 4)
            , test "in Nothing" <|
                \_ ->
                    let
                        -- updatedExample : { bar : Maybe { foo : number, bar : String, qux : Bool }, foo : Maybe a }
                        updatedExample =
                            maybeRecord |> map (L.foo << onJust << L.bar) (\_ -> "Nope")
                    in
                    updatedExample
                        |> access (L.foo << onJust << L.bar)
                        |> Expect.equal Nothing
            , Test.describe
                "dict"
                [ test "set currently present to present" <|
                    \_ ->
                        let
                            updatedDict : Dict String number
                            updatedDict =
                                dict |> map (key "foo") (\_ -> Just 9)
                        in
                        updatedDict
                            |> access (key "foo")
                            |> Expect.equal (Just 9)
                , test "set currently absent to present" <|
                    \_ ->
                        let
                            updatedDict : Dict String number
                            updatedDict =
                                dict |> map (key "bar") (\_ -> Just 9)
                        in
                        updatedDict
                            |> access (key "bar")
                            |> Expect.equal (Just 9)
                , test "set currently present to absent" <|
                    \_ ->
                        let
                            updatedDict : Dict String number
                            updatedDict =
                                dict |> map (key "foo") (\_ -> Nothing)
                        in
                        updatedDict
                            |> access (key "foo")
                            |> Expect.equal Nothing
                , test "set currently absent to absent" <|
                    \_ ->
                        let
                            updatedDict : Dict String number
                            updatedDict =
                                dict |> set (key "bar") Nothing
                        in
                        updatedDict |> access (key "bar") |> Expect.equal Nothing
                , test "set with try present" <|
                    \_ ->
                        let
                            updatedDict : Dict String { bar : String }
                            updatedDict =
                                dictWithRecord |> map (key "foo" << onJust << L.bar) (\_ -> "Sup")
                        in
                        updatedDict
                            |> access (key "foo" << onJust << L.bar)
                            |> Expect.equal (Just "Sup")
                , test "set with try absent" <|
                    \_ ->
                        let
                            updatedDict : Dict String { bar : String }
                            updatedDict =
                                dictWithRecord |> map (key "bar" << onJust << L.bar) (\_ -> "Sup")
                        in
                        updatedDict
                            |> access (key "bar" << onJust << L.bar)
                            |> Expect.equal Nothing
                ]
            ]
        , Test.describe
            "map"
            [ test "simple" <|
                \_ ->
                    let
                        updatedExample : { foo : number, bar : String, qux : Bool }
                        updatedExample =
                            simpleRecord |> map L.bar (\w -> w ++ " lait")
                    in
                    updatedExample.bar
                        |> Expect.equal "Yop lait"
            , test "nested" <|
                \_ ->
                    let
                        updatedExample : { foo : { foo : number, bar : String, qux : Bool } }
                        updatedExample =
                            nestedRecord |> map (L.foo << L.qux) (\w -> not w)
                    in
                    updatedExample.foo.qux
                        |> Expect.equal True
            , test "list" <|
                \_ ->
                    let
                        updatedExample : { bar : List { foo : number, bar : String, qux : Bool } }
                        updatedExample =
                            map (L.bar << List.elementEach << L.foo) (\n -> n - 2) recordWithList
                    in
                    updatedExample
                        |> access (L.bar << List.elementEach << L.foo)
                        |> Expect.equal [ 1, 3 ]
            , test "through Just" <|
                \_ ->
                    let
                        updatedExample : { bar : Maybe { foo : number, bar : String, qux : Bool }, foo : Maybe a }
                        updatedExample =
                            maybeRecord |> map (L.bar << onJust << L.foo) (\n -> n + 3)
                    in
                    updatedExample
                        |> access (L.bar << onJust << L.foo)
                        |> Expect.equal (Just 6)
            , test "through Nothing" <|
                \_ ->
                    let
                        -- updatedExample : { bar : Maybe { foo : number, bar : String, qux : Bool }, foo : Maybe a }
                        updatedExample =
                            maybeRecord |> map (L.foo << onJust << L.bar) (\w -> w ++ "!")
                    in
                    updatedExample
                        |> access (L.foo << onJust << L.bar)
                        |> Expect.equal Nothing
            ]
        , Test.describe
            "overLazy"
            [ test "simple" <|
                \_ ->
                    let
                        updatedExample =
                            simpleRecord |> overLazy L.bar (\w -> w ++ " lait")
                    in
                    updatedExample.bar
                        |> Expect.equal "Yop lait"
            , test "nested" <|
                \_ ->
                    let
                        updatedExample =
                            overLazy (L.foo << L.qux) (\w -> not w) nestedRecord
                    in
                    updatedExample.foo.qux
                        |> Expect.equal True
            , test "list" <|
                \_ ->
                    let
                        updatedExample =
                            overLazy (L.bar << List.elementEach << L.foo) (\n -> n - 2) recordWithList
                    in
                    updatedExample
                        |> access (L.bar << List.elementEach << L.foo)
                        |> Expect.equal [ 1, 3 ]
            , test "through Just" <|
                \_ ->
                    let
                        updatedExample =
                            maybeRecord |> overLazy (L.bar << onJust << L.foo) (\n -> n + 3)
                    in
                    updatedExample
                        |> access (L.bar << onJust << L.foo)
                        |> Expect.equal (Just 6)
            , test "through Nothing" <|
                \_ ->
                    let
                        updatedExample =
                            maybeRecord |> overLazy (L.foo << onJust << L.bar) (\w -> w ++ "!")
                    in
                    updatedExample
                        |> access (L.foo << onJust << L.bar)
                        |> Expect.equal Nothing
            ]
        , Test.describe
            "making accessors"
            [ let
                myFoo =
                    Accessor.for1To1
                        ".foo"
                        .foo
                        (\alter record -> { record | foo = alter record.foo })
              in
              Test.describe
                "Accessor.for1To1"
                [ test "access" <|
                    \_ ->
                        nestedRecord
                            |> access (myFoo << L.bar)
                            |> Expect.equal "Yop"
                , test "set" <|
                    \_ ->
                        let
                            updatedRec : { foo : { foo : number, bar : String, qux : Bool } }
                            updatedRec =
                                nestedRecord |> map (L.foo << myFoo) (\_ -> 1)
                        in
                        updatedRec.foo.foo
                            |> Expect.equal 1
                , test "map" <|
                    \_ ->
                        let
                            updatedRec : { foo : { foo : number, bar : String, qux : Bool } }
                            updatedRec =
                                map (myFoo << myFoo) (\n -> n + 3) nestedRecord
                        in
                        updatedRec.foo.foo
                            |> Expect.equal 6
                ]
            , let
                myOnEach =
                    Accessor.for1ToN
                        "List element List.elementEach"
                        List.map
                        List.map
              in
              Test.describe
                "Accessor."
                [ test "access" <|
                    \_ ->
                        recordWithList
                            |> access (L.bar << myOnEach << L.foo)
                            |> Expect.equal [ 3, 5 ]
                , test "set" <|
                    \_ ->
                        let
                            updatedExample : { bar : List { foo : number, bar : String, qux : Bool } }
                            updatedExample =
                                recordWithList
                                    |> map (L.bar << myOnEach << L.bar) (\_ -> "Greetings")
                        in
                        updatedExample
                            |> access (L.bar << List.elementEach << L.bar)
                            |> Expect.equal [ "Greetings", "Greetings" ]
                , test "map" <|
                    \_ ->
                        let
                            updatedExample : { bar : List { foo : number, bar : String, qux : Bool } }
                            updatedExample =
                                map (L.bar << myOnEach << L.foo) (\n -> n - 2) recordWithList
                        in
                        updatedExample
                            |> access (L.bar << List.elementEach << L.foo)
                            |> Expect.equal [ 1, 3 ]
                ]
            ]
        ]
