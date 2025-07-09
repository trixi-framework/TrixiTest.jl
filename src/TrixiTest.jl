module TrixiTest

using Test: @test, @testset
using TrixiBase: mpi_isroot, trixi_include

include("auxiliary.jl")
include("macros.jl")

export get_kwarg
export @trixi_test_nowarn, @test_trixi_include_base, @timed_testset, @trixi_testset

# re-export methods from TrixiBase
export mpi_isroot, trixi_include

end # module TrixiTest
