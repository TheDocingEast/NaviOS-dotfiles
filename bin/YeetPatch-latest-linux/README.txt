Usage

./YeetPatch.sh update /full/path/to/VotV.exe # or set the path in the script to avoid typing it
./YeetPatch.sh install [-c CACHE_DIR] [--no-backup] [--catalog URL] # args are optional
MUST SET INSTALL_DIR IN THE SCRIPT TO YOUR DESIRED LOCATION OF INSTALLATION FOR THE INSTALL COMMAND TO WORK

At startup the script fetches a notice from `NOTICE_URL` (defaults to `https://votv.dev/patcher_assets/notice`) and prints it
if the file contains any text. Set `NOTICE_URL` to an empty string to skip fetching.
