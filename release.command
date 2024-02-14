DIRECTORY=$(dirname "$0")
cd "$DIRECTORY"


version=$(cat info.json | jq -r '.version')

cd ..
zip -r scootys-armor-swap-$version.zip scootys-armor-swap -x '*.git*' 

echo "Upload to https://mods.factorio.com/mod/scootys-armor-swap/downloads/edit"
say "Done"

