module TrixiTest

using Test: @test, @testset
using TrixiBase: mpi_isroot, trixi_include

include("auxiliary.jl")
include("macros.jl")

export get_kwarg
export @trixi_test_nowarn, @test_trixi_include, @timed_testset, @trixi_testset

end # module TrixiTest
