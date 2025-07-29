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
            @test @isdefined x
            @test x == 4

            @test_trixi_include(path)
            @test @isdefined x
            @test x == 4

            # include and overwrite included variable by a constant
            @test_trixi_include_base(path, x=9)
            @test @isdefined x
            @test x == 9

            @test_trixi_include(path, x=9)
            @test @isdefined x
            @test x == 9

            # include and overwrite included variable by a local variable
            override = 5
            @test_trixi_include_base(path, x=override)
            @test @isdefined x
            @test x == 5

            @test_trixi_include(path, x=override)
            @test @isdefined x
            @test x == 5
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

    @trixi_testset "@test_trixi_include_base with l2 and linf" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, l2=1.0, linf=2.0)
        end
    end

    @trixi_testset "@test_trixi_include_base with l2 and linf variables" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            l2_error = 1.0
            linf_error = 2.0
            @test_trixi_include_base(path, l2=l2_error, linf=linf_error)
        end
    end

    @trixi_testset "@test_trixi_include with l2 and linf" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include(path, l2=1.0, linf=2.0)
        end
    end

    @trixi_testset "@test_trixi_include with l2 and linf variables" begin
        example = """
            function analysis_callback(sol)
             return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            l2_error = 1.0
            linf_error = 2.0
            @test_trixi_include(path, l2=l2_error, linf=linf_error)
        end
    end

    @trixi_testset "maxiters" begin
        example = """
            maxiters = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, maxiters=1)
            @test_trixi_include(path, maxiters=2)

            iters = 3
            @test_trixi_include_base(path, maxiters=iters)
            @test_trixi_include(path, maxiters=iters)
        end
    end
end
