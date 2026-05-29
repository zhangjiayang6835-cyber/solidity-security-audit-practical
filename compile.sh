#!/bin/bash
mkdir -p build
for sol in contracts/*.sol; do
    name=$(basename "$sol" .sol)
    npx solcjs --bin --abi --include-path node_modules --base-path . "$sol" -o build
    echo "Compiled: $name"
done
echo "Done!"
