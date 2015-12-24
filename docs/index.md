# NewPkg.jl

Helper to generate new julia packages.

For *official* information visit the *NewPkg.jl package* [web site and documentation](http://peter1000.github.io/NewPkg.jl/).

## Usage

### config()

    config(force::Bool=false)

Interactive configuration of the development environment.

*NewPkg.jl* operations require `git` minimum configuration that keeps user signature (user.name & user.email).


### generate(pkg, description)

    generate(pkg::AbstractString, description::AbstractString;
                authors::Union{AbstractString, Array} = [],
                authors_url::AbstractString           = "",
                path::AbstractString                  = Pkg.Dir.path(),
                github_name::AbstractString           = "",
                github_ssh::Bool                      = true,
                mkdocs::Bool                          = true
            )

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
* `github_ssh` - if true sets the package repo remote github url to *ssh version* otherwise the *https*, the default
value is `true`.
* `mkdocs` - enables generation of a `mkdocs.yml` configuration file as well as an initial `$pkg/docs` folder, the
default value is `true`.
**Note:** initial `site_url`, `repo_url` ... are generated for github.
