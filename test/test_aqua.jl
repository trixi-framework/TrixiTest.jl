using Aqua: Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(TrixiTest)
    # We do not run tests from ExplicitImports.jl because `@trixi_testset` relies
    # on dynamic includes, which makes the module unanalyzable.
end
