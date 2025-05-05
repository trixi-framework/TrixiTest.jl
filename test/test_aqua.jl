using Aqua: Aqua
using ExplicitImports: check_no_implicit_imports, check_no_stale_explicit_imports

@testset "Aqua.jl" begin
    Aqua.test_all(TrixiTest)
    @test isnothing(check_no_implicit_imports(TrixiTest))
    @test isnothing(check_no_stale_explicit_imports(TrixiTest))
end
