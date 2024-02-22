DIRECTORY=$(dirname "$0")
cd "$DIRECTORY"
cd ..

version=$(cat info.json | jq -r '.version')

cd ..
zip -r scootys-armor-swap-$version.zip scootys-armor-swap -x '*.git*' 

echo "1. Upload to https://mods.factorio.com/mod/scootys-armor-swap/downloads/edit"
echo "2. Delete the scootys-armor-swap folder in mods"
echo "3. Re-launch factorio and update to the new version of the mod"

open ~/Library/Application\ Support/factorio/mods
say "Done"

