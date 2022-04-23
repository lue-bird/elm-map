module VerifyExamples.Accessors.EachIdx3 exposing (..)

-- This file got generated by [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples).
-- Please don't modify this file by hand!

import Test
import Expect

import Accessors exposing (..)
import Lens as L
import Accessors exposing (..)



multiplyIfGTOne : (Int, { bar : Int }) -> (Int, { bar : Int })
multiplyIfGTOne ( idx, ({ bar } as rec) ) =
    if idx > 0 then
        ( idx, { bar = bar * 10 } )
    else
        (idx, rec)
listRecord : {foo : List {bar : Int}}
listRecord = { foo = [ {bar = 2}
                     , {bar = 3}
                     , {bar = 4}
                     ]
             }



spec3 : Test.Test
spec3 =
    Test.test "#eachIdx: \n\n    get (L.foo << eachIdx) listRecord\n    --> [(0, {bar = 2}), (1, {bar = 3}), (2, {bar = 4})]" <|
        \() ->
            Expect.equal
                (
                get (L.foo << eachIdx) listRecord
                )
                (
                [(0, {bar = 2}), (1, {bar = 3}), (2, {bar = 4})]
                )