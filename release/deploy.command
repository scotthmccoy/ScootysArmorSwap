DIRECTORY=$(dirname "$0")
cd "$DIRECTORY"
cd ..

./release/deploy.swift

echo "Tailing factorio-current.log..."
tail -f ~/Library/Application\ Support/factorio/factorio-current.log