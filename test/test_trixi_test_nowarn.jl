macro my_test_nowarn_string(expr, additional_ignore_content = [])
    quote
        add_to_additional_ignore_content = ["[ Info: hi"]
        append!($additional_ignore_content, add_to_additional_ignore_content)
        @trixi_test_nowarn $(esc(expr)) $additional_ignore_content
    end
end

macro my_test_nowarn_regex(expr, additional_ignore_content = [])
    quote
        add_to_additional_ignore_content = [r".*hi"]
        append!($additional_ignore_content, add_to_additional_ignore_content)
        @trixi_test_nowarn $(esc(expr)) $additional_ignore_content
    end
end

@testset "@trixi_test_nowarn" begin
    @trixi_test_nowarn 1 + 1

    @my_test_nowarn_string @info "hi"
    @my_test_nowarn_regex @info "hi"
    a = 1.0
    @my_test_nowarn_string println(a)
end
