__precompile__(true)

"Helper to generate new julia packages."
module NewPkg

export Generate

include("generate.jl")


doc"""
    generate(pkg, description)

Generate a new package named `pkg` with `MIT "Expat" License`.
Generate creates a git repo at `Pkg.dir(pkg)` for the package with an initial file structure.

Arguments:

* `pkg` - a name for the new julia package.
* `description` -  a short description of the new julia package.

Keyword parameters:

* `authors` - a string or array of author names, the final default value will be the `package GitRepo user.name`.
* `authors_url` - a webpage or email address related to the copyright or authors, the final default value will be
  `https://github.com/package GitRepo user.name/`. To skip it set it to `"NONE"`.
* `path` - a location where the package will be generated, the default location is `Pkg.dir()`
* `github_name` - github organisation or user name, the final default value will be `package GitRepo user.name`. To
    skip it set it to `"NONE"`. This is used to set any `package repo remote github url` and any mkdocs: `site_url`,
    `repo_url` etc...
* `github_ssh` - if true sets the package repo remote github url to "ssh version" otherwise the "https", the default
    value is `true`.
* `mkdocs` - enables generation of a `mkdocs.yml` configuration file as well as an initial `$pkg/docs` folder, the
    default value is `true`. <br />
    **Note:** initial `site_url`, `repo_url` ... are generated for github.
"""
generate(pkg::AbstractString, description::AbstractString;
            authors::Union{AbstractString, Array} = [],
            authors_url::AbstractString           = "",
            path::AbstractString                  = Pkg.Dir.path(),
            github_name::AbstractString           = "",
            github_ssh::Bool                      = true,
            mkdocs::Bool                          = true
        ) = Generate.package(pkg, description;
                                authors     = authors,
                                authors_url = authors_url,
                                path        = path,
                                github_name = github_name,
                                github_ssh  = github_ssh,
                                mkdocs      = mkdocs
                            )


"""
    config(force::Bool=false)
Interactive configuration of the development environment.

NewPkg operations require `git` minimum configuration that keeps user signature (user.name & user.email).
"""
function config(force::Bool=false)
    # setup global git configuration
    cfg = LibGit2.GitConfig(LibGit2.Consts.CONFIG_LEVEL_GLOBAL)
    try
        println("Julia NewPkg configuration:")

        username = LibGit2.get(cfg, "user.name", "")
        if isempty(username) || force
            username = LibGit2.prompt("Enter user name", default=username)
            LibGit2.set!(cfg, "user.name", username)
        else
            println("User name: $username")
        end

        useremail = LibGit2.get(cfg, "user.email", "")
        if isempty(useremail) || force
            useremail = LibGit2.prompt("Enter user email", default=useremail)
            LibGit2.set!(cfg, "user.email", useremail)
        else
            println("User email: $useremail")
        end
    finally
        finalize(cfg)
    end
    lowercase(LibGit2.prompt("Do you want to change this configuration?", default="N")) == "y" && config(true)
    return
end


function __init__()
    # Check if git configuration exists
    cfg = LibGit2.GitConfig(LibGit2.Consts.CONFIG_LEVEL_GLOBAL)
    try
        username = LibGit2.get(cfg, "user.name", "")
        if isempty(username)
            warn("Julia NewPkg is not configured. Please, run `NewPkg.config()` before performing any operations.")
        end
    finally
        finalize(cfg)
    end
end

end # module
