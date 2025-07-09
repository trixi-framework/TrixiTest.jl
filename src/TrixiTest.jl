module TrixiTest

using Test: @test, @testset
using TrixiBase: mpi_isroot, trixi_include

include("auxiliary.jl")
include("macros.jl")

export get_kwarg, mpi_isroot
export @trixi_test_nowarn, @test_trixi_include_base, @timed_testset, @trixi_testset

end # module TrixiTest
