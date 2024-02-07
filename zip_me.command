#cd to the directory this file is in
DIRECTORY=$(dirname "$0")
cd "$DIRECTORY"/..

fileName="scootys-armor-swap_1.2.2.zip"
zip -r $fileName scootys-armor-swap -x '*.git*'
cp $fileName /Users/scottmccoy/Library/Application\ Support/factorio/mods/

echo "Upload to https://mods.factorio.com/mod/scootys-armor-swap/downloads/edit"
say "Done"