#!/bin/sh

numruns=${1:-1000}
[ -z "$1" ] && echo "using default numruns: $numruns"

resolver=${2:-}
[ -z "$2" ] && echo "no resolver given, using system default"

hyperfine --runs ${numruns} "nslookup google.com ${resolver}"
