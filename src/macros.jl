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
    @test_trixi_include_base(elixir; additional_ignore_content = Any[],
                                     l2=nothing, linf=nothing, RealT=Float64,
                                     atol=500*eps(RealT), rtol=sqrt(eps(RealT)),
                                     parameters...)

Test an `elixir` file by calling `trixi_include(elixir; parameters...)`.
The `additional_ignore_content` argument is passed to [`@trixi_test_nowarn`](@ref)
and can be used to ignore additional patterns in the `stderr` output.
By default, only the absence of error output is checked.
If `l2` or `linf` are specified, in addition the resulting L2/Linf errors
are compared approximately against these reference values, using `atol, rtol`
as absolute/relative tolerance.
"""
macro test_trixi_include_base(elixir, args...)
    # Note: The variables below are just Symbols, not actual errors/types
    local l2 = get_kwarg(args, :l2, nothing)
    local linf = get_kwarg(args, :linf, nothing)
    local RealT_symbol = get_kwarg(args, :RealT, :Float64)
    RealT = getfield(@__MODULE__, RealT_symbol)
    atol_default = 500 * eps(RealT)
    rtol_default = sqrt(eps(RealT))
    local atol = get_kwarg(args, :atol, atol_default)
    local rtol = get_kwarg(args, :rtol, rtol_default)

    local kwargs = Pair{Symbol, Any}[]
    for arg in args
        if (arg.head == :(=) &&
            !(arg.args[1] in (:additional_ignore_content, :l2, :linf, :RealT, :atol, :rtol)))
            push!(kwargs, Pair(arg.args...))
        end
    end

    # if `maxiters` is set in tests, it is usually set to a small number to
    # run only a few steps - ignore possible warnings coming from that
    if any(==(:maxiters) ∘ first, kwargs)
        args = append_to_kwargs(args, :additional_ignore_content,
                                [
                                    r"┌ Warning: Interrupted\. Larger maxiters is needed\..*\n└ @ SciMLBase .+\n"
                                ])
    end
    local additional_ignore_content = get_kwarg(args, :additional_ignore_content, Any[])

    quote
        mpi_isroot() && println("═"^100)
        mpi_isroot() && println($(esc(elixir)))

        # evaluate examples in the scope of the module they're called from
        @trixi_test_nowarn trixi_include(@__MODULE__, $(esc(elixir)); $kwargs...) $additional_ignore_content

        # if present, compare l2 and linf errors against reference values
        if !isnothing($l2) || !isnothing($linf)
            l2_measured, linf_measured = invokelatest((@__MODULE__).analysis_callback,
                                                      (@__MODULE__).sol)

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
    @timed_testset "name of the testset" #= code to test #=

Similar to `@testset`, but prints the name of the testset and its runtime
after execution.
"""
macro timed_testset(name, expr)
    @assert name isa String
    ex = quote
        local time_start = time_ns()
        @testset $name $expr
        local time_stop = time_ns()
        if mpi_isroot()
            flush(stdout)
            @info("Testset "*$name*" finished in "
                  *string(1.0e-9 * (time_stop - time_start))*" seconds.\n")
            flush(stdout)
        end
    end
    return esc(ex)
end

"""
    @trixi_testset "name of the testset" #= code to test #=

Similar to `@testset`, but wraps the code inside a temporary module to avoid
namespace pollution. It also `include`s this file again to provide the
definition of [`@test_trixi_include_base`](@ref). Moreover, it records the execution time
of the testset similarly to [`@timed_testset`](@ref).
"""
macro trixi_testset(name, expr)
    @assert name isa String
    # TODO: `@eval` is evil
    # We would like to use
    #   mod = gensym(name)
    #   ...
    #   module $mod
    # to create new module names for every test set. However, this is not
    # compatible with the dirty hack using `@eval` to get the mapping when
    # loading structured, curvilinear meshes. Thus, we need to use a plain
    # module name here.
    quote
        local time_start = time_ns()
        @eval module TrixiTestModule
        using Test
        using TrixiTest

        # We also include this file again to provide the definition of
        # the other testing macros. This allows to use `@trixi_testset`
        # in a nested fashion and also call `@trixi_test_nowarn` from
        # there.
        include(@__FILE__)
        # We define `EXAMPLES_DIR` in (nearly) all test modules and use it to
        # get the path to the elixirs to be tested. However, that's not required
        # and we want to fail gracefully if it's not defined.
        try
            import ..EXAMPLES_DIR
        catch
            nothing
        end
        # We usually also define a custom macro `@test_trixi_include`, which is a wrapper
        # around `@test_trixi_include_base` that adds some additional patterns to ignore.
        try
            import ..@test_trixi_include
        catch
            nothing
        end
        @testset $name $expr
        end
        local time_stop = time_ns()
        if mpi_isroot()
            flush(stdout)
            @info("Testset "*$name*" finished in "
                  *string(1.0e-9 * (time_stop - time_start))*" seconds.\n")
        end
        nothing
    end
end

"""
    @test_allocations(rhs!, semi, sol, allocs)

Test that the memory allocations of `rhs!` are below `allocs`
(e.g., from type instabilities), where `rhs!` is a function with
a method `rhs!(du, u, semi, t)`.
"""
macro test_allocations(rhs!, semi, sol, allocs)
    quote
        t = $(esc(sol)).t[end]
        u = $(esc(sol)).u[end]
        du = similar(u)
        @test (@allocated $(esc(rhs!))(du, u, $(esc(semi)), t)) < $(esc(allocs))
    end
end
