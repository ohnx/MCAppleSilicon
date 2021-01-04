#!/bin/bash

# configuration variables
# id of keys store in keychain
KEYCHAIN_ID="MCAppleSilicon"
# google drive file id for zip
TANMAY_MCAS_BINS="1ihlfFLiNkVWM2pwR4ujjBAVKZMplC2CI"
# name of directory where we store all the binaries/libraries
LIBDIR_NAME="MCAppleSilicon"
# full path to the directory - may not exist
LIBS_LOCATION=$(echo ~/Library/Application\ Support/$LIBDIR_NAME)

# display dialog
dialog(){
    if [ $# -eq 2 ]; then
        mode="with icon $2"
    else
        mode=" "
    fi
    osascript -e "display dialog \"$1\" $mode buttons {\"OK\"}"  2>&1
}

# download from google drive
gdrive_download(){
    cookiejar=$TMPDIR"cookies-$RANDOM.txt"
    touch "$cookiejar"
    echo "initial request to google drive"
    confirmkey=$(curl -s --cookie-jar "$cookiejar" "https://drive.google.com/uc?id=$1&export=download" | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')
    if [ -z "$confirmkey" ]; then
        dialog "Failed to send initial request to fetch assets from Google Drive!" stop
        return 1
    fi

    echo "downloading file..."
    curl -L --cookie "$cookiejar" "https://drive.google.com/uc?export=download&confirm=$confirmkey&id=$1" -o $2
    retcode=$?
    # clear cookie jar
    rm -rf "$cookiejar"
    if [[ $retcode -ne 0 ]]; then
        # failure :(
        dialog "cURL download to $2 failed!" stop
    fi

    return $retcode
}

# download assets
download_assets(){
    filename=$TMPDIR"mcas-$RANDOM.zip"
    gdrive_download "$TANMAY_MCAS_BINS" "$filename"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    mkdir -p "$LIBS_LOCATION"
    if [[ $? -ne 0 ]]; then
        dialog "Cannot create location to store files in $LIBS_LOCATION" stop
        rm -rf "$LIBS_LOCATION" $filename
        return 1
    fi
    unzip $filename -d "$LIBS_LOCATION"
    if [[ $? -ne 0 ]]; then
        dialog "Cannot extract files to destination; was the download corrupted?" stop
        rm -rf "$LIBS_LOCATION" $filename
        return 1
    fi
    mv "$LIBS_LOCATION"/MCAppleSilicon/* "$LIBS_LOCATION"
    # clean up
    rm -rf "$LIBS_LOCATION"/__MACOSX "$LIBS_LOCATION"/MCAppleSilicon $filename
    # success
    return 0
}

setup_assets(){
    if [ -d "$LIBS_LOCATION" ]; then
        # assets should already be set up
        return 0
    fi

    dialog "Looks like this is your first time setting things up.\nAsset download will begin when you press 'OK'; this process might take a while. Please be patient!"

    # create and download assets to assets directory
    download_assets
    if [[ $? -ne 0 ]]; then
        dialog "failed"
        return 1
    fi

    dialog "Press 'OK' to download additional Minecraft assets...\n(This will also take a while; please be patient!)"

    # run setup scripts, per https://gist.github.com/tanmayb123/d55b16c493326945385e815453de411a
    cd "$LIBS_LOCATION/libraries"
    sh download.sh
    cd ..
    python3 downloadassets.py

    dialog "We might request keychain access in a second.\nThis might look scary, but please just press 'Always Allow'.\nThis permission lets us store your Minecraft credentials securely."

    # all done!
    return 0
}

# configure keychain
configure_keychain(){
# prompt user for username
read -r -d '' get_username_script << EOF
set theResponse to display dialog "Minecraft username/Mojang email:" default answer "" with icon note buttons {"Cancel", "OK"} default button "OK"
return theResponse
EOF

# prompt user for password
read -r -d '' get_password_script << EOF
set theResponse to display dialog "Password:" default answer "" with icon note buttons {"Cancel", "OK"} default button "OK" with hidden answer
return theResponse
EOF

# the output of a successful
successful_msg="button returned:OK, text returned:"

username_return=$(osascript -e "$get_username_script" 2>&1)
# check for success
if [[ "$username_return" == "$successful_msg"* ]]; then
    echo "applescript return: $username_return"
    password_return=$(osascript -e "$get_password_script" 2>&1)
    if [[ "$password_return" == "$successful_msg"* ]]; then
        echo "applescript return: $password_return"
        username=${username_return#"$successful_msg"}
        password=${password_return#"$successful_msg"}
        echo "fetched username: $username"
        echo "fetched password: $password"
        # add this info to the keychain
        output=$(security add-generic-password -s "$KEYCHAIN_ID" -a "$username" -w "$password")
        retval=$?
        if retval; then
            dialog "Failed to configure keychain:\n$output" stop
        fi
        return retval
    else
        return 1
    fi
else
    return 1
fi
}

# check if asset download necessary
setup_assets
if [[ $? -ne 0 ]]; then
    exit 1
fi

# check if keychain configuration necessary
if [[ $(security find-generic-password -s "$KEYCHAIN_ID" -g 2>&1) == "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain"* ]]; then
    # configure keychain
    configure_keychain
    if [[ $? -ne 0 ]]; then
        # failure :(
        exit 1
    fi
fi

# launch the game
info=$(security find-generic-password -s "$KEYCHAIN_ID" -g 2>&1 | grep -E "acct|password" |  rev  | cut -d'"' -f2 | rev)
read -r passwd uname <<< $info

cd "$LIBS_LOCATION"
sh launch.sh $uname $passwd
