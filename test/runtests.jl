using Test
using TrixiTest

@testset verbose=true "TrixiTest.jl Tests" begin
    include("test_aqua.jl")
    include("test_trixi_test_nowarn.jl")
end
