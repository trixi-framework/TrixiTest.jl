module TestAllocations
function rhs!(du, u, semi, t)
    # Simulate some computation
    du .= u .+ t
    return nothing
end
end

@testset "@test_allocations" begin
    semi = nothing
    sol = (t = [1.0], u = [[1.0, 2.0]])
    allocs = 1
    @test_allocations(TestAllocations.rhs!, semi, sol, allocs)
end
