#cd to the directory this file is in
DIRECTORY=$(dirname "$0")
cd $DIRECTORY
DIRECTORY=$(pwd)

cd ..

echo "Creating zip..."
fileName="scootys-armor-swap_1.2.1.zip"
zip -r $fileName scootys-armor-swap -x '*.git*'
echo "Upload $filename to https://mods.factorio.com/mod/scootys-armor-swap/downloads/edit when ready to release"

echo "Copying folder to factorio application support. Remember to delete zip from mod directory."
rsync -av --exclude=".*" $DIRECTORY /Users/scottmccoy/Library/Application\ Support/factorio/mods/
echo "Reload Save for mod changes to take effect."

echo "Tailing factorio logs..."
echo ""
tail -f /Users/scottmccoy/Library/Application\ Support/factorio/factorio-current.log