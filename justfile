# Usage: just <module> <recipe> [args]   e.g. `just flutter analyze`, `just api run`

mod flutter 'code/flutter'
mod go 'code/api'

[private]
default:
    @just --list --list-submodules
