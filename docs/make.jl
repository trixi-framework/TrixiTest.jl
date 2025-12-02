using Documenter

# Get TrixiTest.jl root directory
trixitest_root_dir = dirname(@__DIR__)

# Fix for https://github.com/trixi-framework/Trixi.jl/issues/668
if (get(ENV, "CI", nothing) != "true") &&
   (get(ENV, "TRIXITEST_DOC_DEFAULT_ENVIRONMENT", nothing) != "true")
    push!(LOAD_PATH, trixitest_root_dir)
end

using TrixiTest

# Define module-wide setups such that the respective modules are available in doctests
DocMeta.setdocmeta!(TrixiTest, :DocTestSetup, :(using TrixiTest); recursive = true)

# Copy files to not need to synchronize them manually
function copy_file(filename, replaces...; new_filename = lowercase(filename))
    content = read(joinpath(trixitest_root_dir, filename), String)
    content = replace(content, replaces...)

    header = """
    ```@meta
    EditURL = "https://github.com/trixi-framework/TrixiTest.jl/blob/main/$filename"
    ```
    """
    content = header * content

    write(joinpath(@__DIR__, "src", new_filename), content)
end

copy_file("README.md", new_filename = "index.md")
copy_file("AUTHORS.md",
          "in the [LICENSE.md](LICENSE.md) file" => "under [License](@ref)")
# Add section `# License` and add `>` in each line to add a quote
copy_file("LICENSE.md",
          "[AUTHORS.md](AUTHORS.md)" => "[Authors](@ref)",
          "\n" => "\n> ", r"^" => "# License\n\n> ")

# Make documentation
makedocs(modules = [TrixiTest],
         sitename = "TrixiTest.jl",
         # Provide additional formatting options
         format = Documenter.HTML(
                                  # Disable pretty URLs during manual testing
                                  prettyurls = get(ENV, "CI", nothing) == "true",
                                  # Set canonical URL to GitHub pages URL
                                  canonical = "https://trixi-framework.github.io/TrixiTest.jl/stable"),
         # Explicitly specify documentation structure
         pages = [
             "Home" => "index.md",
             "API reference" => "reference.md",
             "Authors" => "authors.md",
             "License" => "license.md"
         ])

deploydocs(;
           repo = "github.com/trixi-framework/TrixiTest.jl",
           devbranch = "main",
           # Only push previews if all the relevant environment variables are non-empty.
           push_preview = all(!isempty,
                              (get(ENV, "GITHUB_TOKEN", ""),
                               get(ENV, "DOCUMENTER_KEY", ""))))
