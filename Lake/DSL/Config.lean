/-
Copyright (c) 2021 Mac Malone. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mac Malone
-/
import Lean.Elab.ElabRules
import Lake.DSL.Extensions

namespace Lake.DSL
open Lean Elab Term

/--
A dummy default constant for `__dir__` to make it type check
outside Lakefile elaboration (e.g., when editing).
-/
constant dummyDir : System.FilePath

/--
A dummy default constant for `__args__` to make it type check
outside Lakefile elaboration (e.g., when editing).
-/
constant dummyArgs : List String

/--
A macro that expands to the path of package's directory
during the Lakefile's elaboration.
-/
scoped elab stx:"__dir__" : term <= expectedType? => do
  let exp :=
    if let some dir := dirExt.getState (← getEnv) then
      let str := Syntax.mkStrLit dir.toString (SourceInfo.fromRef stx)
      Syntax.mkApp (mkCIdentFrom stx ``System.FilePath.mk) #[str]
    else
      -- `id` app forces Lean to show macro's doc rather than the constant's
      Syntax.mkApp (mkCIdentFrom stx ``id) #[mkCIdentFrom stx ``dummyDir]
  withMacroExpansion stx exp <| elabTerm exp expectedType?

/--
A macro that expands to the configuration arguments passed
via the Lake command line during the Lakefile's elaboration.
-/
scoped elab stx:"__args__" : term <= expectedType? => do
  let exp :=
    if let some args := argsExt.getState (← getEnv) then
      quote args
    else
      -- `id` app forces Lean to show macro's doc rather than the constant's
      Syntax.mkApp (mkCIdentFrom stx ``id) #[mkCIdentFrom stx ``dummyArgs]
  withMacroExpansion stx exp <| elabTerm exp expectedType?