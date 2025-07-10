# Get the first value assigned to `keyword` in `args` and return `default_value`
# if there are no assignments to `keyword` in `args`.
function get_kwarg(args, keyword, default_value)
    val = default_value
    for arg in args
        if arg.head == :(=) && arg.args[1] == keyword
            val = arg.args[2]
            break
        end
    end
    return val
end

# Look for `keyword` in `args` and append `value` to its array of values.
# If `keyword` does not exist, create an assignment of a vector containing `value`
# to `keyword`. The new `args` is returned!
function append_to_kwargs(args, keyword, value)
    found = false
    for arg in args
        if arg.head == :(=) && arg.args[1] == keyword
            append!(arg.args[2].args, value)
            found = true
            break
        end
    end
    if !found
        args = (:($keyword = [$(value...)]), args...)
    end
    return args
end
