macro test_trixi_include(expr, args...)
    local add_to_additional_ignore_content = [r"┌ Warning: Test warning\n└ @ .+\n"]
    args = append_to_kwargs(args, :additional_ignore_content,
                            add_to_additional_ignore_content)
    ex = quote
        @test_trixi_include_base($expr, $(args...))
    end
    return esc(ex)
end

@testset verbose=true "@test_trixi_include_base and @test_trixi_include" begin
    @trixi_testset "basic" begin
        example = """
            x = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            # just include
            @test_trixi_include_base(path)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 4

            @test_trixi_include(path)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 4

            # include and overwrite included variable by a constant
            @test_trixi_include_base(path, x=9)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 9

            @test_trixi_include(path, x=9)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 9
        end
    end

    @trixi_testset "advanced" begin
        example = """
            seed = 42
            x = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            # overwrite included variable by a (global) variable
            global override = 5
            @test_trixi_include_base(path, x=override)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 5

            @test_trixi_include(path, x=override)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 5

            # overwrite included variable by another included variable
            @test_trixi_include_base(path, x=seed)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 42

            @test_trixi_include(path, x=seed)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 42

            # overwrite included variable by supplied variable
            @test_trixi_include_base(path, seed=6, x=seed)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 6

            @test_trixi_include(path, seed=6, x=seed)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :x)
            @test (@invokelatest mod.x) == 6
        end
    end

    @trixi_testset "normal override, all assignment forms" begin
        global f(; x = 0) = x
        example = """
            x = 1
            x_kw_pos  = f(x = 1)
            x_kw_semi = f(; x = 1)
            y = (; x = 1)
            function g(; x = 1)
                return x
            end
            y_g = g()
            function h(x = 1)
                return x
            end
            y_h = h()
            y_let = 0
            y_let_global = 0
            let x = 1
                y_let = x
                global y_let_global = x
            end
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, x=6)
            mod = @__MODULE__
            @test (@invokelatest mod.x) == 6
            @test (@invokelatest mod.x_kw_pos) == 6
            @test (@invokelatest mod.x_kw_semi) == 6
            @test (@invokelatest mod.y).x == 6
            @test (@invokelatest mod.y_g) == 6
            @test (@invokelatest mod.y_h) == 6
            @test (@invokelatest mod.y_let) == 0 # let block introduces a local scope
            @test (@invokelatest mod.y_let_global) == 6
        end
    end

    @trixi_testset "chained override, all assignment forms" begin
        global f(; x = 0) = x
        example = """
            seed = 42
            x = 1
            x_kw_pos  = f(x = 1)
            x_kw_semi = f(; x = 1)
            y = (; x = 1)
            function g(; x = 1)
                return x
            end
            y_g = g()
            function h(x = 1)
                return x
            end
            y_h = h()
            y_let = 0
            y_let_global = 0
            let x = 1
                y_let = x
                global y_let_global = x
            end
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, seed=6, x=seed)
            mod = @__MODULE__
            @test (@invokelatest mod.x) == 6
            @test (@invokelatest mod.x_kw_pos) == 6
            @test (@invokelatest mod.x_kw_semi) == 6
            @test (@invokelatest mod.y).x == 6
            @test (@invokelatest mod.y_g) == 6
            @test (@invokelatest mod.y_h) == 6
            @test (@invokelatest mod.y_let) == 0 # let block introduces a local scope
            @test (@invokelatest mod.y_let_global) == 6
        end
    end

    @trixi_testset "locally defined override, all assignment forms" begin
        global f(; x = 0) = x
        example = """
            x = 1
            x_kw_pos  = f(x = 1)
            x_kw_semi = f(; x = 1)
            y = (; x = 1)
            function g(; x = 1)
                return x
            end
            y_g = g()
            function h(x = 1)
                return x
            end
            y_h = h()
            y_let = 0
            y_let_global = 0
            let x = 1
                y_let = x
                global y_let_global = x
            end
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            # overwrite included variable by a locally defined value (not a module global)
            local_x = 6
            @test_trixi_include_base(path, x=local_x)
            mod = @__MODULE__
            @test (@invokelatest mod.x) == 6
            @test (@invokelatest mod.x_kw_pos) == 6
            @test (@invokelatest mod.x_kw_semi) == 6
            @test (@invokelatest mod.y).x == 6
            @test (@invokelatest mod.y_g) == 6
            @test (@invokelatest mod.y_h) == 6
            @test (@invokelatest mod.y_let) == 0 # let block introduces a local scope
            @test (@invokelatest mod.y_let_global) == 6
        end
    end

    @trixi_testset "compound (non-Symbol) override values" begin
        # Regression test for a bug where compound kwarg values (e.g. function
        # calls) were evaluated in the testset module from which the macro is
        # called instead of in the elixir's scope. This broke values referencing
        # names that are only available *inside* the elixir, such as
        # `surface_flux=FluxLaxFriedrichs(max_abs_speed)` in Trixi.jl, where
        # `FluxLaxFriedrichs` and `max_abs_speed` come from the elixir's own
        # `using Trixi` and are not defined in the (inner) testset module.
        #
        # We mimic this here with `norm` from `LinearAlgebra`: the elixir brings
        # it in via its own `using LinearAlgebra`, while the testset module from
        # which the macros are called below does *not* have `LinearAlgebra` (and
        # `norm` is therefore not defined there).
        example = """
            using LinearAlgebra
            x = norm([3.0, 4.0])
            t = (1, 2)
            s = "default"
            """

        mktemp() do path, io
            write(io, example)
            close(io)
            mod = @__MODULE__

            # `norm` is intentionally not available in this testset module, so
            # evaluating the override value here (instead of in the elixir's
            # scope) would throw an `UndefVarError`.
            @test !(@invokelatest isdefined(mod, :norm))

            # Compound call expression referencing an elixir-internal name
            @test_trixi_include_base(path, x=norm([6.0, 8.0]))
            @test (@invokelatest mod.x) ≈ 10.0

            @test_trixi_include(path, x=norm([6.0, 8.0]))
            @test (@invokelatest mod.x) ≈ 10.0

            # Tuple expression
            @test_trixi_include_base(path, t=(3, 4))
            @test (@invokelatest mod.t) == (3, 4)

            @test_trixi_include(path, t=(3, 4))
            @test (@invokelatest mod.t) == (3, 4)

            # String literal
            @test_trixi_include_base(path, s="override")
            @test (@invokelatest mod.s) == "override"

            # Numeric literal still works through the same code path
            @test_trixi_include_base(path, x=7)
            @test (@invokelatest mod.x) == 7

            # Combining a compound override with a chained Symbol override:
            # `t=(x, x)` must be resolved in the elixir's scope *after* the
            # `x` override has been applied there.
            @test_trixi_include_base(path, x=norm([5.0, 12.0]), t=(x, x))
            @test (@invokelatest mod.x) ≈ 13.0
            @test all((@invokelatest mod.t) .≈ (13.0, 13.0))
        end
    end

    # The following two testsets are regression tests for the failures observed in
    # Trixi.jl's CI with TrixiBase.jl v0.1.11. There, bare-Symbol kwarg values were
    # quoted before being spliced into the elixir, so that they ended up as `Symbol`
    # *values* instead of references to the variables they name. Since
    # `@test_trixi_include_base` passes elixir-internal names as bare `Symbol`s
    # (case 3 in `src/macros.jl`), an override such as
    #   @test_trixi_include_base(elixir, initial_condition=initial_condition_xyz)
    # then assigned `initial_condition = :initial_condition_xyz` in the elixir.
    # These tests do not depend on Trixi.jl and reproduce the two failure modes
    # seen there (a `Symbol` used as a function and a `Symbol` used as a number).
    #
    # Note that the name used as the override value must be defined *only* inside
    # the respective elixir and must not already be defined in the (fresh) testset
    # module when the macro is expanded. Otherwise `@isdefined` succeeds on
    # Julia < 1.12 and the value is passed instead of the `Symbol`, which does not
    # exercise this code path. Hence the two examples per testset below use
    # different names for the function/value used as the override.
    @trixi_testset "elixir-internal Symbol override used as a function" begin
        # Reproduces `MethodError: objects of type Symbol are not callable`.
        # The two examples are included into the *same* testset module, so they must
        # not define methods of the same function: that would emit a "Method
        # definition ... overwritten" warning on `stderr`, which
        # `@trixi_test_nowarn` (rightfully) reports as a failure. Hence the default
        # is `identity` from `Base` and only the override targets are defined here.
        example_base = """
            initial_condition_base(x) = 2.0

            initial_condition = identity
            u0 = initial_condition(0.0)
            """
        example_wrapper = """
            initial_condition_wrapper(x) = 3.0

            initial_condition = identity
            u0 = initial_condition(0.0)
            """

        mktemp() do path, io
            write(io, example_base)
            close(io)
            mod = @__MODULE__

            # The override value is only defined inside the elixir, so it has to be
            # passed through to `trixi_include` as an unquoted `Symbol`.
            @test !(@invokelatest isdefined(mod, :initial_condition_base))

            @test_trixi_include_base(path, initial_condition=initial_condition_base)
            @test (@invokelatest mod.u0) == 2.0
        end

        mktemp() do path, io
            write(io, example_wrapper)
            close(io)
            mod = @__MODULE__

            @test !(@invokelatest isdefined(mod, :initial_condition_wrapper))

            @test_trixi_include(path, initial_condition=initial_condition_wrapper)
            @test (@invokelatest mod.u0) == 3.0
        end
    end

    @trixi_testset "elixir-internal Symbol override used as a number" begin
        # Reproduces `MethodError: no method matching isless(::Symbol, ::Int64)`.
        example_base = """
            maxiters_base = 3

            maxiters = 100
            finished = 5 > maxiters
            """
        example_wrapper = """
            maxiters_wrapper = 4

            maxiters = 100
            finished = 5 > maxiters
            """

        mktemp() do path, io
            write(io, example_base)
            close(io)
            mod = @__MODULE__

            @test !(@invokelatest isdefined(mod, :maxiters_base))

            @test_trixi_include_base(path, maxiters=maxiters_base)
            @test (@invokelatest mod.maxiters) == 3
            @test (@invokelatest mod.finished) == true
        end

        mktemp() do path, io
            write(io, example_wrapper)
            close(io)
            mod = @__MODULE__

            @test !(@invokelatest isdefined(mod, :maxiters_wrapper))

            @test_trixi_include(path, maxiters=maxiters_wrapper)
            @test (@invokelatest mod.maxiters) == 4
            @test (@invokelatest mod.finished) == true
        end
    end

    @trixi_testset "additional_ignore_content" begin
        example = """
            @warn "Test warning"
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path,
                                     additional_ignore_content=[r"┌ Warning: Test warning\n└ @ .+\n"])

            # same test, but @test_trixi_include already knows about the additional warning
            @test_trixi_include(path)

            # same test, with the additional warning added twice
            @test_trixi_include(path,
                                additional_ignore_content=[r"┌ Warning: Test warning\n└ @ .+\n"])
        end
    end

    @trixi_testset "l2 and linf (base)" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            global l2_error = 1.0
            @test_trixi_include_base(path, l2=l2_error, linf=2.0)
        end
    end

    @trixi_testset "l2 and linf" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            global linf_error = 2.0
            @test_trixi_include(path, l2=1.0, linf=linf_error)
        end
    end

    @trixi_testset "l2 and linf with DoubleFloats" begin
        using DoubleFloats: Double64
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include(path, l2=Double64(1.0), linf=Double64(2.0))
        end
    end

    @testset "l2 and linf with DoubleFloats and normal @testset" begin
        using DoubleFloats: Double64
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include(path, l2=Double64(1.0), linf=Double64(2.0))
        end
    end

    @trixi_testset "l2 and linf with RealT_for_test_tolerances" begin
        example = """
            function analysis_callback(sol)
            @show sol
            return sol[1], sol[2]
            end
            sol = [1.2345678901234567, 7.6543210987654321]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, l2=1.2345, linf=7.6543,
                                     RealT_for_test_tolerances=Float32)
        end
    end

    @trixi_testset "maxiters" begin
        example = """
            maxiters = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            global iters = 3
            @test_trixi_include_base(path, maxiters=2)
            @test_trixi_include(path, maxiters=iters)
        end
    end

    @trixi_testset "RealT" begin
        example = """
            RealT = Float64
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, RealT=Float32)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :RealT)
            @test (@invokelatest mod.RealT) == Float32

            @test_trixi_include(path, RealT=Float32)
            mod = @__MODULE__
            @test @invokelatest isdefined(mod, :RealT)
            @test (@invokelatest mod.RealT) == Float32
        end
    end
end


# The macros above are not the only way `trixi_include` is used in downstream
# packages: some of them define their own, ad-hoc test macros that hand the
# unevaluated kwarg expressions straight to `trixi_include`, e.g.
# `SummationByPartsOperatorsExtra.jl` in `test/test_util.jl`:
#
#     macro test_trixi_include(example, args...)
#         local kwargs = Pair{Symbol, Any}[]
#         for arg in args
#             if arg.head == :(=)
#                 push!(kwargs, Pair(arg.args...))
#             end
#         end
#         quote
#             @trixi_test_nowarn trixi_include(@__MODULE__, $example; $kwargs...)
#         end
#     end
#
# A bare identifier such as `xmin=xmin` therefore reaches `trixi_include` as the
# `Symbol` `:xmin`, and is expected to be spliced into the elixir as a *variable
# reference* that is resolved in the scope the elixir is included into. Since
# `TrixiTest.jl` re-exports `trixi_include` and is run as a downstream test of
# `TrixiBase.jl`, we pin down that contract here as well. It is not covered by
# the testsets above, which go through `@test_trixi_include_base` and hence
# never pass a bare `Symbol` to `trixi_include`.
@testset verbose=true "trixi_include with bare Symbol values" begin
    @trixi_testset "bare Symbol kwargs are resolved as variable references" begin
        # Reproduces the failure of `SummationByPartsOperatorsExtra.jl` with
        # TrixiBase.jl v0.1.11, where the `Symbol`s were quoted and thus ended up
        # as `Symbol` *values* in the elixir:
        #   MethodError: no method matching
        #       (CoordRefSystems.Cartesian{CoordRefSystems.NoDatum})(::Tuple{Symbol, Symbol})
        # from `Box((xmin, ymin), (xmax, ymax))` in `examples/RBF_MFSBP.jl`.
        example = """
            make_box(min::NTuple{2, Float64}, max::NTuple{2, Float64}) = (min, max)

            xmin = -1.0
            xmax = 1.0
            ymin = -1.0
            ymax = 1.0
            geometry = make_box((xmin, ymin), (xmax, ymax))
            """

        mktemp() do path, io
            write(io, example)
            close(io)
            mod = @__MODULE__

            # The values the elixir-internal assignments are overwritten with are
            # globals of the module the elixir is included into, exactly as in a
            # `@testitem`/`@trixi_testset` body of a downstream package.
            global xmin = -2.0
            global xmax = 2.0
            global ymin = -3.0
            global ymax = 3.0

            @trixi_test_nowarn trixi_include(mod, path;
                                             xmin = :xmin, xmax = :xmax,
                                             ymin = :ymin, ymax = :ymax)

            @test (@invokelatest mod.geometry) == ((-2.0, -3.0), (2.0, 3.0))
        end
    end
end
