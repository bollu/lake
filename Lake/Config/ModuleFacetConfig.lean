/-
Copyright (c) 2022 Mac Malone. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mac Malone
-/
import Lake.Build.Info
import Lake.Build.Store

namespace Lake
open Lean System

/-- A Module facet's declarative configuration. -/
structure ModuleFacetConfig where
  /-- The name of the facet. -/
  facet : WfName
  /-- The type of the facet's build result. -/
  resultType : Type
  /-- The module facet's build function. -/
  build : {m : Type → Type} →
    [Monad m] → [MonadLift BuildM m] → [MonadBuildStore m] →
    Module → IndexT m (ActiveBuildTarget resultType)
  /-- Proof that module facet's build result is the correctly typed target.-/
  data_eq_target : ModuleData facet = ActiveBuildTarget resultType

instance : Inhabited ModuleFacetConfig := ⟨{
  facet := &`lean.bin
  resultType := PUnit
  build := default
  data_eq_target := eq_dynamic_type
}⟩

hydrate_opaque_type OpaqueModuleFacetConfig ModuleFacetConfig

instance {cfg : ModuleFacetConfig}
: DynamicType ModuleData cfg.facet (ActiveBuildTarget cfg.resultType) :=
  ⟨cfg.data_eq_target⟩

/-- Try to find a module facet configuration in the package with the given name . -/
def Package.findModuleFacetConfig? (name : Name) (self : Package) : Option ModuleFacetConfig :=
  self.opaqueModuleFacetConfigs.find? name |>.map (·.get)