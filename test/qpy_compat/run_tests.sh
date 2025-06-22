#!/bin/bash

# This code is part of Qiskit.
#
# (C) Copyright IBM 2021.
#
# This code is licensed under the Apache License, Version 2.0. You may
# obtain a copy of this license in the LICENSE.txt file in the root directory
# of this source tree or at http://www.apache.org/licenses/LICENSE-2.0.
#
# Any modifications or derivative works of this code must retain this
# copyright notice, and modified files need to carry a notice indicating
# that they have been altered from the originals.
set -e
set -o pipefail
set -x
shopt -s nullglob

# Set fixed hash seed to ensure set orders are identical between saving and
# loading.
export PYTHONHASHSEED=$(python -S -c "import random; print(random.randint(1, 4294967295))")
echo "PYTHONHASHSEED=$PYTHONHASHSEED"

our_dir="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
repo_root="$(realpath -- "$our_dir/../..")"

# First, prepare a wheel file for the dev version.  We install several venvs with this, and while
# cargo will cache some rust artefacts, it still has to re-link each time, so the wheel build takes
# a little while.
wheel_dir="$(pwd -P)/wheels"
python -m pip wheel --no-deps --wheel-dir "$wheel_dir" "$repo_root"
all_wheels=("$wheel_dir"/*.whl)
qiskit_dev_wheel="${all_wheels[0]}"

# Now set up a "base" development-version environment, which we'll use for most of the backwards
# compatibility checks.
qiskit_venv="$(pwd -P)/venvs/dev"
qiskit_python="$qiskit_venv/bin/python"
python -m venv "$qiskit_venv"

# `packaging` is needed for the `get_versions.py` script.
"$qiskit_venv/bin/pip" install -c "$repo_root/constraints.txt" "$qiskit_dev_wheel" packaging "symengine<0.14" "sympy>1.3"

# Run all of the tests of cross-Qiskit-version compatibility.
"$qiskit_python" "$our_dir/get_versions.py" | parallel -j 2 --colsep=" " bash "$our_dir/process_version.sh" -p "$qiskit_python"

# Test dev compatibility with itself.
dev_version="$("$qiskit_python" -c 'import qiskit; print(qiskit.__version__)')"
mkdir -p "dev-files/base"
pushd "dev-files/base"
"$qiskit_python" "$our_dir/test_qpy.py" generate --version="$dev_version"
"$qiskit_python" "$our_dir/test_qpy.py" load --version="$dev_version"
popd
