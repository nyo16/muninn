#!/usr/bin/env bash

set -e

# Run tests with NIF compilation enabled
export MUNINN_BUILD=true
mix test "$@"
