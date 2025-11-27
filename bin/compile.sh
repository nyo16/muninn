#!/usr/bin/env bash

set -e

# Compile the project with NIF compilation enabled
export MUNINN_BUILD=true
mix compile "$@"
