/-
Copyright (c) 2022 Mac Malone. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mac Malone
-/
import Lake.Build.Info
import Lake.Build.Store
import Lake.Build.Targets

namespace Lake

/-! # Build Static Lib -/

/-- Build and collect the specified facet of the library's local modules. -/
def LeanLib.recBuildLocalModules
(facets : Array (ModuleFacet α)) (self : LeanLib) : IndexT RecBuildM (Array α) := do
  let mut results := #[]
  let mut modSet := ModuleSet.empty
  let mods ← self.getModuleArray
  for mod in mods do
    let (_, mods) ← mod.imports.recBuild
    let mods := mods.push mod
    for mod in mods do
      if self.isLocalModule mod.name then
        unless modSet.contains mod do
          for facet in facets do
            results := results.push <| ← recBuild <| mod.facet facet.name
          modSet := modSet.insert mod
  return results

protected def LeanLib.recBuildLean
(self : LeanLib) : IndexT RecBuildM ActiveOpaqueTarget := do
  ActiveTarget.collectOpaqueArray (i := PUnit) <|
    ← self.recBuildLocalModules #[Module.leanBinFacet]

protected def LeanLib.recBuildStatic
(self : LeanLib) : IndexT RecBuildM ActiveFileTarget := do
  let oTargets := (← self.recBuildLocalModules self.nativeFacets).map Target.active
  staticLibTarget self.staticLibFile oTargets |>.activate

/-! # Build Shared Lib -/

/--
Build and collect the local object files and external libraries
of a library and its modules' imports.
-/
def LeanLib.recBuildLinks (self : LeanLib)
: IndexT RecBuildM (Array ActiveFileTarget) := do
  -- Build and collect modules
  let mut pkgs := #[]
  let mut pkgSet := PackageSet.empty
  let mut modSet := ModuleSet.empty
  let mut targets := #[]
  let mods ← self.getModuleArray
  for mod in mods do
    let (_, mods) ← mod.imports.recBuild
    let mods := mods.push mod
    for mod in mods do
      unless modSet.contains mod do
        unless pkgSet.contains mod.pkg do
            pkgSet := pkgSet.insert mod.pkg
            pkgs := pkgs.push mod.pkg
        if self.isLocalModule mod.name then
          for facet in self.nativeFacets do
            targets := targets.push <| ← recBuild <| mod.facet facet.name
        modSet := modSet.insert mod
  -- Build and collect external library targets
  for pkg in pkgs do
    let externLibTargets ← pkg.externLibs.mapM (·.shared.recBuild)
    for target in externLibTargets do
      targets := targets.push target
  return targets

protected def LeanLib.recBuildShared
(self : LeanLib) : IndexT RecBuildM ActiveFileTarget := do
  let linkTargets := (← self.recBuildLinks).map Target.active
  leanSharedLibTarget self.sharedLibFile linkTargets self.linkArgs |>.activate

/-! # Build Executable -/

protected def LeanExe.recBuildExe
(self : LeanExe) : IndexT RecBuildM ActiveFileTarget := do
  let (_, imports) ← self.root.imports.recBuild
  let linkTargets := #[Target.active <| ← self.root.o.recBuild]
  let mut linkTargets ← imports.foldlM (init := linkTargets) fun arr mod => do
    let mut arr := arr
    for facet in mod.nativeFacets do
      arr := arr.push <| Target.active <| ← recBuild <| mod.facet facet.name
    return arr
  let deps := (← recBuild <| self.pkg.facet `deps).push self.pkg
  for dep in deps do for lib in dep.externLibs do
    linkTargets := linkTargets.push <| Target.active <| ← lib.static.recBuild
  leanExeTarget self.file linkTargets self.linkArgs |>.activate
