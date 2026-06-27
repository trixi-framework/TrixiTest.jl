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
