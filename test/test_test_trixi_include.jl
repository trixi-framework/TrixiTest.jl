macro test_trixi_include(expr, additional_ignore_content = [])
    quote
        add_to_additional_ignore_content = [r"┌ Warning: Test warning\n└ @ .+\n"]
        append!($additional_ignore_content, add_to_additional_ignore_content)
        @test_trixi_include_base($(esc(expr)), additional_ignore_content = $additional_ignore_content)
    end
end

@testset verbose=true "@test_trixi_include_base" begin
    @trixi_testset "basic" begin
        example = """
            x = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path)

            @test @isdefined x
            @test x == 4

            @test_trixi_include_base(path, x=9)

            @test @isdefined x
            @test x == 9
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
            @test_trixi_include(path)
        end
    end

    @trixi_testset "with l2 and linf" begin
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

    @trixi_testset "maxiters" begin
        example = """
            maxiters = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include_base(path, maxiters=1)
        end
    end
end
