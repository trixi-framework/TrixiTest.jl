# Get the first value assigned to `keyword` in `args` and return `default_value`
# if there are no assignments to `keyword` in `args`.
function get_kwarg(args, keyword, default_value)
    val = default_value
    for arg in args
        if arg.head == :(=) && arg.args[1] == keyword
            val = arg.args[2]
            break
        end
    end
    return val
end

# Look for `keyword` in `args` and append `value` to its array of values.
# If `keyword` does not exist, create an assignment of a vector containing `value`
# to `keyword`. The new `args` is returned!
function append_to_kwargs(args, keyword, value)
    found = false
    for arg in args
        if arg.head == :(=) && arg.args[1] == keyword
            append!(arg.args[2].args, value)
            found = true
            break
        end
    end
    if !found
        args = (:($keyword = [$(value...)]), args...)
    end
    return args
end

"""
    trixi_include_kwargs(args; reserved = ())

Turn the arguments `args` of a testing macro (a tuple of `:(key = value)` expressions, as
they are received by a macro) into a vector of `Expr(:kw, ...)` expressions that can be
spliced into a `trixi_include` (from [TrixiBase.jl](https://github.com/trixi-framework/TrixiBase.jl))
call inside the expression the macro returns:

```julia
macro my_test_include(example, args...)
    local kwargs = trixi_include_kwargs(args; reserved = (:l2, :linf))
    quote
        @trixi_test_nowarn trixi_include(@__MODULE__, \$(esc(example)); \$(kwargs...))
        # Use the values passed to the `reserved` arguments `l2` and `linf`.
    end
end
```

Keys listed in `reserved` are consumed by the calling macro itself and are skipped, i.e.,
they are not forwarded to `trixi_include`.

This is used by [`@test_trixi_include_base`](@ref) and encapsulates how the unevaluated
keyword arguments of a testing macro have to be passed on to `trixi_include`.

For bare-symbol values there are three cases:
  1. Symbol is also a key in this kwarg list (e.g. `seed=6, x=seed`): pass an expression
     so that `trixi_include` resolves it inside the example after the other override
     (`seed=6`) has been applied.
  2. Locally-defined values defined in the testset body: `@isdefined` returns true (same
     world age), so the actual value is passed.
  3. Example-internal variable references (e.g. bare `x=seed` with no `seed=` key): on
     Julia >= 1.12, `@isdefined` returns false because bindings set inside `Base.include`
     have a newer world age; on older Julia the value is visible and also correct (same as
     the example default).
Example-internal bare symbols are wrapped in a block expression. This preserves
example-scope evaluation without passing a `Symbol` *value* to `trixi_include`, which
treats a `Symbol` as a literal value.

For non-Symbol expressions, there are two cases:
  4. Literals (numbers, strings, quoted Symbols, ...): the value is the same regardless of
     the scope, so we can simply pass it on. Note that a quoted symbol literal such as
     `x=:foo` is parsed as a `QuoteNode`, not as a `Symbol`, and hence lands here and is
     passed on as the value `:foo`.
  5. Compound expressions (calls, tuples, array/closure literals, e.g.
     `surface_flux=FluxLaxFriedrichs(max_abs_speed)`): these typically reference names that
     are only available *inside* the example's scope (e.g. brought in by the example's own
     `using Trixi`) and are not defined at the macro call site (the testset module). Hence,
     we must NOT evaluate them at the call site but pass the unevaluated expression through
     to `trixi_include`, which splices it into the example and evaluates it in the
     example's scope.
Both of the latter are achieved by passing the expression on unevaluated via a `QuoteNode`.
"""
function trixi_include_kwargs(args; reserved = ())
    is_forwarded(arg) = arg.head == :(=) && !(arg.args[1] in reserved)

    kwarg_keys = Set(arg.args[1] for arg in args if is_forwarded(arg))
    kwarg_exprs = Expr[]
    for arg in args
        is_forwarded(arg) || continue
        key, val = arg.args
        if val isa Symbol && val in kwarg_keys
            # Case 1: chained override — resolve the reference in the example
            push!(kwarg_exprs, Expr(:kw, key, QuoteNode(Expr(:block, val))))
        elseif val isa Symbol
            # Cases 2 & 3: use @isdefined to capture locally-defined values while
            # falling back to an expression that resolves example-internal references
            # in the example
            push!(kwarg_exprs,
                  Expr(:kw, key,
                       esc(:((@isdefined $val) ? $val :
                             $(QuoteNode(Expr(:block, val)))))))
        else
            # Cases 4 & 5: pass literals and compound expressions on unevaluated
            push!(kwarg_exprs, Expr(:kw, key, QuoteNode(val)))
        end
    end
    return kwarg_exprs
end
