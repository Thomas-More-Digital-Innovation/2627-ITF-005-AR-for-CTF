# Usage: just <module> <recipe> [args]   e.g. `just flutter analyze`, `just api dev`

mod flutter 'code/flutter'
mod api 'code/api'

[private]
default:
    @just --list --list-submodules
