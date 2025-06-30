using Test: @test
using TrixiBase: mpi_isroot, trixi_include

"""
    @trixi_test_nowarn expr [additional_ignore_content]

Modified version of `@test_nowarn expr` that prints the content of `stderr` when
it is not empty and ignores some common info statements. Additional patterns
that should be ignored can be passed as a list of strings or regular
expressions.
"""
macro trixi_test_nowarn(expr, additional_ignore_content = String[])
    quote
        let fname = tempname()
            try
                ret = open(fname, "w") do f
                    redirect_stderr(f) do
                        $(esc(expr))
                    end
                end
                stderr_content = read(fname, String)
                if !isempty(stderr_content)
                    println("Content of `stderr`:\n", stderr_content)
                end

                # Patterns matching the following ones will be ignored. Additional patterns
                # passed as arguments can also be regular expressions, so we just use the
                # type `Any` for `ignore_content`.
                ignore_content = Any["[ Info: You just called `trixi_include`. Julia may now compile the code, please be patient.\n"]
                append!(ignore_content, $additional_ignore_content)
                for pattern in ignore_content
                    stderr_content = replace(stderr_content, pattern => "")
                end

                # We also ignore simple module redefinitions for convenience. Thus, we
                # check whether every line of `stderr_content` is of the form of a
                # module replacement warning.
                @test occursin(r"^(WARNING: replacing module .+\.\n)*$", stderr_content)
                ret
            finally
                rm(fname, force = true)
            end
        end
    end
end

"""
    @test_trixi_include(elixir; l2=nothing, linf=nothing, RealT=Float64,
                                atol=500*eps(RealT), rtol=sqrt(eps(RealT)),
                                parameters...)

Test Trixi by calling `trixi_include(elixir; parameters...)`.
By default, only the absence of error output is checked.
If `l2` or `linf` are specified, in addition the resulting L2/Linf errors
are compared approximately against these reference values, using `atol, rtol`
as absolute/relative tolerance.
"""
macro test_trixi_include(elixir, args...)
    # Note: The variables below are just Symbols, not actual errors/types
    local l2 = get_kwarg(args, :l2, nothing)
    local linf = get_kwarg(args, :linf, nothing)
    local RealT = get_kwarg(args, :RealT, :Float64)
    if RealT === :Float64
        atol_default = 500 * eps(Float64)
        rtol_default = sqrt(eps(Float64))
    elseif RealT === :Float32
        atol_default = 500 * eps(Float32)
        rtol_default = sqrt(eps(Float32))
    elseif RealT === :Float128
        atol_default = 500 * eps(Float128)
        rtol_default = sqrt(eps(Float128))
    elseif RealT === :Double64
        atol_default = 500 * eps(Double64)
        rtol_default = sqrt(eps(Double64))
    end
    local atol = get_kwarg(args, :atol, atol_default)
    local rtol = get_kwarg(args, :rtol, rtol_default)

    local kwargs = Pair{Symbol, Any}[]
    for arg in args
        if (arg.head == :(=) &&
            !(arg.args[1] in (:l2, :linf, :RealT, :atol, :rtol)))
            push!(kwargs, Pair(arg.args...))
        end
    end

    quote
        mpi_isroot() && println("═"^100)
        mpi_isroot() && println($(esc(elixir)))

        # if `maxiters` is set in tests, it is usually set to a small number to
        # run only a few steps - ignore possible warnings coming from that
        if any(==(:maxiters) ∘ first, $kwargs)
            additional_ignore_content = [
                r"┌ Warning: Interrupted\. Larger maxiters is needed\..*\n└ @ SciMLBase .+\n",
                r"┌ Warning: Interrupted\. Larger maxiters is needed\..*\n└ @ Trixi .+\n"]
        else
            additional_ignore_content = []
        end

        # evaluate examples in the scope of the module they're called from
        @trixi_test_nowarn trixi_include(@__MODULE__, $(esc(elixir)); $kwargs...) additional_ignore_content

        # if present, compare l2 and linf errors against reference values
        if !isnothing($l2) || !isnothing($linf)
            l2_measured, linf_measured = invokelatest(analysis_callback, sol)

            if mpi_isroot() && !isnothing($l2)
                @test length($l2) == length(l2_measured)
                for (l2_expected, l2_actual) in zip($l2, l2_measured)
                    @test isapprox(l2_expected, l2_actual, atol = $atol, rtol = $rtol)
                end
            end

            if mpi_isroot() && !isnothing($linf)
                @test length($linf) == length(linf_measured)
                for (linf_expected, linf_actual) in zip($linf, linf_measured)
                    @test isapprox(linf_expected, linf_actual, atol = $atol, rtol = $rtol)
                end
            end
        end

        mpi_isroot() && println("═"^100)
        mpi_isroot() && println("\n\n")
    end
end

"""
    @trixi_testset "name of the testset" #= code to test #=

Similar to `@testset`, but wraps the code inside a temporary module to avoid
namespace pollution.
"""
macro trixi_testset(name, expr)
    @assert name isa String

    mod = gensym()

    # TODO: `@eval` is evil
    quote
        @eval module $mod
        using Test
        using TrixiTest

        # We also include this file again to provide the definition of
        # the other testing macros. This allows to use `@trixi_testset`
        # in a nested fashion and also call `@test_nowarn_mod` from
        # there.
        include(@__FILE__)

        @testset verbose=true $name $expr
        end

        nothing
    end
end
