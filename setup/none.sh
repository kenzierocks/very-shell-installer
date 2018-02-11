#!/usr/bin/env bash

# Special script for environments we don't support. Takes an extra argument specifying the environment name.
printf 'vsi does not support %s. Please contribute if you would like this to work!\n' "$1" >&2
exit 1
