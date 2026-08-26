# Changelog

TrixiTest.jl follows the interpretation of
[semantic versioning (semver)](https://julialang.github.io/Pkg.jl/dev/compatibility/#Version-specifier-format-1)
used in the Julia ecosystem. Notable changes will be documented in this file
for human readability.

## Changes in the v0.2 lifecycle

#### Added

- New function `trixi_include_kwargs` that turns the arguments of a
  testing macro into a vector of `Expr(:kw, ...)` expressions that
  can be spliced into a `trixi_include` call inside the expression
  the macro returns ([#40]).

## Breaking changes from v0.1.x to v0.2

- The keyword argument `RealT` in the macro `@test_trixi_include_base`
  has been renamed to `RealT_for_test_tolerances` to avoid name clashes
  when passing a keyword argument `RealT` ([#20]).
