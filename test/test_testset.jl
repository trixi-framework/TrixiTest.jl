@timed_testset "@timed_testset" begin
    sleep(0.2)
    @test true
end

module TestTrixiTest
using TrixiTest

EXAMPLES_DIR = "TEST_DIR"

@trixi_testset "EXAMPLES_DIR" begin
    @test @isdefined EXAMPLES_DIR

    @trixi_testset "EXAMPLES_DIR nested" begin
        @test @isdefined EXAMPLES_DIR
    end
end
end
