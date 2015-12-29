module Generate

import Base.Pkg.PkgError
importall Base.LibGit2

copyright_year() = string(Dates.year(Dates.today()))
copyright_name(repo::GitRepo) = LibGit2.getconfig(repo, "user.name", "")

function package(pkg::AbstractString, description::AbstractString;
                    authors::Union{AbstractString, Array} = "",
                    authors_url::AbstractString          = "",
                    path::AbstractString                 = Pkg.Dir.path(),
                    github_name::AbstractString          = "",
                    github_ssh::Bool                     = true,
                    mkdocs::Bool                         = true
                )

    pkg_path = joinpath(path, pkg)
    ispath(pkg_path) && throw(PkgError("$pkg seems to exit: Path <$pkg_path>  To remove it use: `Pkg.rm`"))
    isempty(description) && throw(PkgError("`description` may not be empty."))

    year = copyright_year()
    try
        repo = Generate.init(pkg_path, github_name, github_ssh)
        LibGit2.transact(repo) do repo
            if isempty(authors)
                authors = copyright_name(repo)
            end

            if isempty(authors_url)
                authors_url = "https://github.com/$(copyright_name(repo))/"
            end

            if isempty(github_name)
                github_name = LibGit2.getconfig(repo, "user.name", "")
            end

            files = [Generate.license(pkg_path, year, authors, authors_url),
                     Generate.readme(pkg_path, description, github_name),
                     Generate.tests(pkg_path),
                     Generate.require(pkg_path),
                     Generate.gitignore(pkg_path),
                     Generate.entrypoint(pkg_path, description),
                     Generate.todo(pkg_path),
                     Generate.changelog(pkg_path),
                    ]
            mkdocs && push!(files, Generate.mkdocs(pkg_path, description, year, authors, authors_url, github_name))

            msg = """
            $pkg.jl "generated" files.

                authors:  $(join(vcat(authors),", "))
                authors info url: $authors_url
                year:    $year

            Julia Version $VERSION [$(Base.GIT_VERSION_INFO.commit_short)]
            """
            LibGit2.add!(repo, files..., flags = LibGit2.Consts.INDEX_ADD_FORCE)
            info("Committing $pkg generated files")
            LibGit2.commit(repo, msg)
        end
    catch
        rm(pkg_path, recursive=true)
        rethrow()
    end
    return
end


function init(pkg::AbstractString, github_name::AbstractString, github_ssh::Bool)
    ispath(pkg) && throw(PkgError("$pkg seems to exit: Path <$pkg_path"))

    pkg_name = basename(pkg)
    info("Initializing $pkg_name repo: $pkg")
    repo = LibGit2.init(pkg)
    try
        LibGit2.commit(repo, "initial empty commit")
    catch err
        throw(PkgError("Unable to initialize $pkg_name package: $err"))
    end

    if isempty(github_name)
        github_name = LibGit2.getconfig(repo, "user.name", "")
    end

    try
        if github_name != "NONE"
            if github_ssh
                repo_url = "git@github.com:$(github_name)/$(pkg_name).jl.git"
            else
                repo_url = "https://github.com/$(github_name)/$(pkg_name).jl/"
            end
            info("Origin: $repo_url")
            with(LibGit2.GitRemote, repo, "origin", repo_url) do rmt
                LibGit2.save(rmt)
            end
            LibGit2.set_remote_url(repo, repo_url)
        end
    end
    return repo
end


function genfile(f::Function, pkg::AbstractString, file::AbstractString)
    path = joinpath(pkg, file)
    if !ispath(path)
        info("Generating $file")
        mkpath(dirname(path))
        open(f, path, "w")
        return file
    end
    return ""
end


function copyright(year::AbstractString, authors::Array, authors_url::AbstractString)
    text = "> Copyright (c) $year - $year:"
    for author in authors
        text *= "\n>  * $author"
    end
    if authors_url != "NONE"
        text *= "\n>"
        text *= "\n> Authors info: $authors_url"
        text *= "\n>"
    end
    return text
end


function copyright(year::AbstractString, authors::AbstractString, authors_url::AbstractString)
    if authors_url != "NONE"
        return "> Copyright (c) $year - $year: **$authors**. &nbsp; (<$authors_url>)"
    else
        return "> Copyright (c) $year - $year: **$authors**."
    end
end


function license(pkg::AbstractString,
                 year::AbstractString,
                 authors::Union{AbstractString,Array},
                 authors_url::AbstractString)
    pkg_name = basename(pkg)
    genfile(pkg,"LICENSE.md") do io
        println(io, "## Copyrights & Licenses")
        println(io)
        println(io, "The *$pkg_name.jl package* is licensed under the MIT \"Expat\" License:")
        println(io)
        println(io, copyright(year, authors, authors_url))
        lic=readall(normpath(dirname(@__FILE__), "..", "res", "licenses_MIT"))
        for l in split(lic,['\n','\r'])
            println(io, "> ", l)
        end
        println(io)
        println(io, "### Licenses for incorporated software")
        println(io)
        println(io, "The *$pkg_name.jl package* contains some code derived from the following sources, ",
                           "which have their own licenses:")
        println(io)
    end
end


function readme(pkg::AbstractString,
                description::AbstractString,
                github_name::AbstractString
                )
    pkg_name = basename(pkg)
    genfile(pkg,"README.md") do io
        println(io, "## $(pkg_name).jl")
        println(io)
        println(io, "$description")
        println(io)
        if github_name != "NONE"
            println(io, "### Web Presence")
            println(io)
            println(io, "* $(pkg_name).jl [web site and documentation]",
                        "(http://$(lowercase(github_name)).github.io/$(pkg_name).jl/)")
            println(io, "* $(pkg_name).jl [github repository](https://github.com/$(github_name)/$(pkg_name).jl/)")
            println(io)
        end
    end
end


function tests(pkg::AbstractString)
    pkg_name = basename(pkg)
    genfile(pkg,"test/runtests.jl") do io
        print(io, """
        using $pkg_name
        using Base.Test

        # write your own tests here
        @test 1 == 1
        """)
    end
end


function versionfloor(ver::VersionNumber)
    # return "major.minor" for the most recent release version relative to ver
    # for prereleases with ver.minor == ver.patch == 0, return "major-" since we
    # don't know what the most recent minor version is for the previous major
    if isempty(ver.prerelease) || ver.patch > 0
        return string(ver.major, '.', ver.minor)
    elseif ver.minor > 0
        return string(ver.major, '.', ver.minor - 1)
    else
        return string(ver.major, '-')
    end
end


function todo(pkg::AbstractString)
    genfile(pkg,"TODO.md") do io
        print(io, "## TODO")
        print(io)
    end
end


function require(pkg::AbstractString)
    genfile(pkg,"REQUIRE") do io
        print(io, """
        julia $(versionfloor(VERSION))
        """)
    end
end


function gitignore(pkg::AbstractString)
    genfile(pkg,".gitignore") do io
        print(io, """
        *.jl.cov
        *.jl.*.cov
        *.jl.mem

        # MkDocs build
        site/
        """)
    end
end


function entrypoint(pkg::AbstractString, description::AbstractString)
    pkg_name = basename(pkg)
    genfile(pkg,"src/$pkg_name.jl") do io
        print(io, """#__precompile__(true)

            "$description"
            module $pkg_name

            # package code goes here

            end # module
            """)
    end
end


function mkdocs_yml(pkg::AbstractString,
                    description::AbstractString,
                    year::AbstractString,
                    authors::Union{AbstractString, Array},
                    authors_url::AbstractString,
                    github_name::AbstractString
                    )
    pkg_name = basename(pkg)
    genfile(pkg,"mkdocs.yml") do io
        println(io, "site_name:        $(pkg_name).jl")
        github_name != "NONE" && println(io, "site_url:         https://$(github_name).github.io/$(pkg_name).jl/")
        println(io, "site_description: $(description)")
        println(io, "site_author:      $(authors)")
        println(io, "site_favicon:     images/$(lowercase(pkg_name))_favicon.ico")
        println(io)
        github_name != "NONE" && println(io, "repo_url:         https://github.com/$(github_name)/$(pkg_name).jl/")
        println(io)
        println(io, "pages:")
        println(io, "- Home: 'index.md'")
        println(io)
        println(io, "- About:")
        println(io, "    - Readme: about/readme.md")
        println(io, "    - License: about/license.md")
        println(io, "    - Changelog: about/changelog.md")
        println(io)
        println(io, "use_directory_urls: true")
        println(io, "copyright: Copyright (c) $(year) - $(year), <strong>$(authors)</strong> ",
                    "<a href=\"$(authors_url)\">$(authors_url)</a>.")
        println(io)
        println(io, "theme: 'bootstrap'")
        println(io)
    end
end


function docs_index(pkg::AbstractString,
                    description::AbstractString,
                    year::AbstractString,
                    authors::Union{AbstractString, Array},
                    authors_url::AbstractString,
                    github_name::AbstractString
                    )
    pkg_name = basename(pkg)
    genfile(pkg,"docs/index.md") do io
        println(io, "# $(pkg_name).jl")
        println(io)
        println(io, "$(description)")
        println(io)
        if github_name != "NONE"
            println(io, "For *official* information visit the *$(pkg_name).jl package* [web site and documentation]",
                        "(http://$(lowercase(github_name)).github.io/$(pkg_name).jl/).")
            println(io)
        end
    end
end


function mkdocs(pkg::AbstractString,
                    description::AbstractString,
                    year::AbstractString,
                    authors::Union{AbstractString, Array},
                    authors_url::AbstractString,
                    github_name::AbstractString
                    )
    # dirs and links
    images_path = joinpath(pkg, "docs", "images")
    mkpath(images_path)
    touch(joinpath(images_path, ".gitkeep"))

    about_path = joinpath(pkg, "docs", "about")
    mkpath(joinpath(about_path, "readme", "images"))
    touch(joinpath(about_path, "readme", "images", ".gitkeep"))

    cd(about_path)
    symlink(joinpath(pkg, "README.md"), "readme.md")
    symlink(joinpath(pkg, "LICENSE.md"), "license.md")
    symlink(joinpath(pkg, "CHANGELOG.md"), "changelog.md")
    cd(normpath(dirname(@__FILE__)))

    #
    mkdocs_yml(pkg, description, year, authors, authors_url, github_name)
    docs_index(pkg, description, year, authors, authors_url, github_name)
end


function changelog(pkg::AbstractString)
    pkg_name = basename(pkg)
    genfile(pkg,"CHANGELOG.md") do io
        print(io, """
            ## v0.1.0 (xxxx-xx-xx)

            ### Summary


            -----------------------------------------------------------------------------------------------------------------------

            ## P-Versioning Based On [Semantic Versioning](http://semver.org/)

            **IMPORTANT DIFFERENCE** to the *Semantic Versioning 2.0.0* <br />

            * A pre-release version MUST NOT be added.

            * Build metadata MUST comprise only ASCII alphanumerics [0-9A-Za-z] and MUST NOT contain any hyphen.

            ### Package Versioning

            1. **Software and related packages using this modified Semantic Versioning MUST declare a public API.** This API could
                be declared in the code itself or exist strictly in documentation. However it is done, it should be precise and
                comprehensive.

            2. A normal version number MUST take the form X.Y.Z where X, Y, and Z are non-negative integers, and MUST NOT contain
                leading zeroes. X is the major version, Y is the minor version, and Z is the patch version.
                Each element MUST increase numerically. For instance: 1.9.0 -> 1.10.0 -> 1.11.0.

            3. Once a versioned package has been released, the contents of that version MUST NOT be modified. Any modifications
                MUST be released as a new version.

            4. Major version zero (0.y.z) is for initial development. Anything may change at any time. The public API should not be
                considered stable.

            5. **Version 1.0.0 defines the public API. The way in which the version number is incremented after this release is
                dependent on this public API and how it changes.**

            6. Patch version Z (x.y.Z | x > 0) MUST be incremented if only backwards compatible bug fixes are introduced. A bug fix
                is defined as an internal change that fixes incorrect behavior.

            7. Minor version Y (x.Y.z | x > 0) MUST be incremented if new, backwards compatible functionality is introduced to the
                public API. It MUST be incremented if any public API functionality is marked as deprecated. It MAY be incremented
                if substantial new functionality or improvements are introduced within the private code. It MAY include patch level
                changes. Patch version MUST be reset to 0 when minor version is incremented.

            8. Major version X (X.y.z | X > 0) MUST be incremented if any backwards incompatible changes are introduced to the
                public API. It MAY include minor and patch level changes. Patch and minor version MUST be reset to 0 when major
                version is incremented.

            9. Build metadata MAY be denoted by appending a plus sign and a series of dot separated identifiers immediately
                following the patch version. Identifiers MUST comprise only ASCII alphanumerics [0-9A-Za-z] and MUST NOT contain
                hyphen. Identifiers MUST NOT be empty. Build metadata SHOULD be ignored when determining version precedence. Thus
                two versions that differ only in the build metadata, have the same precedence. <br />
                Examples: 1.0.0+001, 1.0.0+20130313144700, 1.0.0+exp.sha.5114f85, 1.0.7+r128.g4560914.

            * What do I do if I accidentally release a backwards incompatible change as a minor version?

                As soon as you realize that you've broken the Semantic Versioning spec, fix the problem and release a new minor
                version that corrects the problem and restores backwards compatibility. Even under this circumstance, it is
                unacceptable to modify versioned releases. If it's appropriate, document the offending version and inform your
                users of the problem so that they are aware of the offending version.

            * How should I handle deprecating functionality?

                Deprecating existing functionality is a normal part of software development and is often required to make forward
                progress. When you deprecate part of your public API, you should do two things:

                1. update your documentation to let users know about the change,
                2. issue a new minor release with the deprecation in place. Before you completely remove the functionality in a new
                    major release there should be at least one minor release that contains the deprecation so that users can
                    smoothly transition to the new API.

            """)
    end
end


end # module
