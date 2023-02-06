#cd to the directory this file is in
DIRECTORY=$(dirname "$0")
cd "$DIRECTORY"/..

zip -r scootys-armor-swap_1.1.0.zip scootys-armor-swap
say "Done"