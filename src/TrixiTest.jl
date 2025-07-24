module TrixiTest

using Test: @inferred, @test, @test_broken, @test_deprecated, @test_logs,
            @test_nowarn, @test_skip, @test_throws, @test_warn, @testset
using TrixiBase: mpi_isroot, trixi_include

include("auxiliary.jl")
include("macros.jl")

export get_kwarg, append_to_kwargs
export @trixi_test_nowarn, @test_trixi_include_base, @timed_testset, @trixi_testset,
       @test_allocations

# re-export methods from TrixiBase
export mpi_isroot, trixi_include

end # module TrixiTest
