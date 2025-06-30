@testset verbose=true "@test_trixi_include" begin
    @trixi_testset "basic" begin
        example = """
            x = 4
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include(path)

            @test @isdefined x
            @test x == 4

            @trixi_test_nowarn trixi_include(@__MODULE__, path, x = 7)

            @test x == 7
        end
    end

    @trixi_testset "with l2" begin
        example = """
            function analysis_callback(sol)
	            return sol[1], sol[2]
            end
            sol = [1.0, 2.0]
            """

        mktemp() do path, io
            write(io, example)
            close(io)

            @test_trixi_include(path, l2 = 1.0)
        end
    end
end
