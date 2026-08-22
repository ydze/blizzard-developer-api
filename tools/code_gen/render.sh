#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

source .venv/bin/activate

python render.py --template templates/csharp.j2 --input schema.json