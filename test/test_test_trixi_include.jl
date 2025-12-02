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
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 4
            else
                @test @isdefined x
                @test x == 4
            end

            @test_trixi_include(path)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 4
            else
                @test @isdefined x
                @test x == 4
            end

            # include and overwrite included variable by a constant
            @test_trixi_include_base(path, x=9)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 9
            else
                @test @isdefined x
                @test x == 9
            end

            @test_trixi_include(path, x=9)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 9
            else
                @test @isdefined x
                @test x == 9
            end
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
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 5
            else
                @test @isdefined x
                @test x == 5
            end

            @test_trixi_include(path, x=override)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 5
            else
                @test @isdefined x
                @test x == 5
            end

            # overwrite included variable by another included variable
            @test_trixi_include_base(path, x=seed)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 42
            else
                @test @isdefined x
                @test x == 42
            end

            @test_trixi_include(path, x=seed)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 42
            else
                @test @isdefined x
                @test x == 42
            end

            # overwrite included variable by supplied variable
            @test_trixi_include_base(path, seed=6, x=seed)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 6
            else
                @test @isdefined x
                @test x == 6
            end

            @test_trixi_include(path, seed=6, x=seed)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :x)
                @test (@invokelatest mod.x) == 6
            else
                @test @isdefined x
                @test x == 6
            end
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

    # RealT is used internally to compute error tolerances when l2 or linf are used
    # However, it should also be forwarded as a keyword argument to trixi_include
    @trixi_testset "RealT" begin
        example = """
            RealT = Float64
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, RealT=Float32)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :RealT)
                @test (@invokelatest mod.RealT) == Float32
            else
                @test @isdefined RealT
                @test RealT == Float32
            end

            @test_trixi_include(path, RealT=Float32)
            if VERSION >= v"1.12"
                mod = @__MODULE__
                @test @invokelatest isdefined(mod, :RealT)
                @test (@invokelatest mod.RealT) == Float32
            else
                @test @isdefined RealT
                @test RealT == Float32
            end
        end
    end
end
