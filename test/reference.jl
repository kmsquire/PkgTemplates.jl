const STATIC_FILE = joinpath(@__DIR__, "fixtures", "static.txt")
const STATIC_DOCUMENTER = [
    PackageSpec(; name="DocStringExtensions", version=v"0.8.1"),
    PackageSpec(; name="Documenter", version=v"0.24.2"),
    PackageSpec(; name="JSON", version=v"0.21.0"),
    PackageSpec(; name="Parsers", version=v"0.3.10"),
]

PT.user_view(::Citation, ::Template, ::AbstractString) = Dict("MONTH" => 8, "YEAR" => 2019)
PT.user_view(::License, ::Template, ::AbstractString) = Dict("YEAR" => 2019)

function pin_documenter(project_dir::AbstractString)
    @suppress PT.with_project(project_dir) do
        foreach(Pkg.add, STATIC_DOCUMENTER)
    end
    toml = joinpath(project_dir, "Project.toml")
    project = TOML.parsefile(toml)
    filter!(p -> p.first == "Documenter", project["deps"])
    open(io -> TOML.print(io, project), toml, "w")
end

function test_all(pkg::AbstractString; kwargs...)
    t = tpl(; kwargs...)
    with_pkg(t, pkg) do pkg
        pkg_dir = joinpath(t.dir, pkg)
        PT.hasplugin(t, Documenter) && pin_documenter(joinpath(pkg_dir, "docs"))
        foreach(readlines(`git -C $pkg_dir ls-files`)) do f
            reference = joinpath(@__DIR__, "fixtures", pkg, f)
            observed = read(joinpath(pkg_dir, f), String)
            @test_reference reference observed
        end
    end
end

@testset "Reference tests" begin
    @testset "Default package" begin
        test_all("Basic"; authors=USER)
    end

    @testset "All plugins" begin
        test_all("AllPlugins"; authors=USER, plugins=[
            AppVeyor(), CirrusCI(), Citation(), Codecov(), CompatHelper(), Coveralls(),
            Develop(), Documenter(), DroneCI(), GitHubActions(), GitLabCI(), TravisCI(),
        ])
    end

    @testset "Documenter (TravisCI)" begin
        test_all("DocumenterTravis"; authors=USER, plugins=[
            Documenter{TravisCI}(), TravisCI(),
        ])
    end

    @testset "Documenter (GitHubActions)" begin
        test_all("DocumenterGitHubActions"; authors=USER, plugins=[
            Documenter{GitHubActions}(), GitHubActions(),
        ])
    end


    @testset "Wacky options" begin
        test_all("WackyOptions"; authors=USER, julia=v"1.2", plugins=[
            AppVeyor(; x86=true, coverage=true, extra_versions=[v"1.1"]),
            CirrusCI(; image="freebsd-123", coverage=false, extra_versions=["1.1"]),
            Citation(; readme=true),
            Codecov(; file=STATIC_FILE),
            Coveralls(; file=STATIC_FILE),
            Documenter{GitLabCI}(
                assets=[STATIC_FILE],
                makedocs_kwargs=Dict(:foo => "bar", :bar => "baz"),
                canonical_url=(_t, _pkg) -> "http://example.com",
            ),
            DroneCI(; amd64=false, arm=true, arm64=true, extra_versions=["1.1"]),
            Git(; ignore=["a", "b", "c"], manifest=true),
            GitHubActions(; x86=true, linux=false, coverage=false),
            GitLabCI(; coverage=false, extra_versions=[v"0.6"]),
            License(; name="ISC"),
            ProjectFile(; version=v"1"),
            Readme(; inline_badges=true),
            TagBot(; registry="Foo/Bar", dispatch=true),
            Tests(; project=true),
            TravisCI(;
                coverage=false,
                windows=false,
                x86=true,
                arm64=true,
                extra_versions=["1.1"],
            ),
        ])
    end
end
