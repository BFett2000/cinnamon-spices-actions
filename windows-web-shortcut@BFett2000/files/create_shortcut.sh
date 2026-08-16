#!/bin/bash

# Get the folder where the user right-clicked
if [ -n "$1" ]; then
    DEST=$(realpath "$1")
else
    DEST=$(xdg-user-dir DESKTOP)
fi

# Confirm URL of the link
URL=$(zenity --entry --width=250 --title "Shortcut Location" --text="Enter the URL or file path for this shortcut:" --entry-text="")
if [ -z "$URL" ]; then
    notify-send --expire-time=200000 "Shortcut creation canceled."
    exit 1
fi

# Confirm name of the shortcut
NAME=$(zenity --entry --width=250 --title "Shortcut Name" --text="Enter a name for this shortcut:" --entry-text="")
if [ -z "$NAME" ]; then
    notify-send --expire-time=200000 "Shortcut creation canceled."
    exit 1
fi

# Check if the shortcut already exists
if [ -e "$DEST/$NAME.desktop" ]; then
    notify-send --expire-time=200000 "Error: $DEST/$NAME.desktop already exists."
    exit 1
fi

# Determine Icon Based on Target Type
if [ -d "$URL" ]; then
    # Local Folder Target: Query Nemo's metadata for a custom icon path
    CUSTOM_ICON=$(gio info -a "metadata::custom-icon" "$URL" | grep "metadata::custom-icon:" | cut -d' ' -f4-)

    if [ -n "$CUSTOM_ICON" ]; then
        ICON_ID="$CUSTOM_ICON"
    else
        ICON_ID="folder"
    fi
else
    # External Web Target: Isolate domain to fetch the dynamic web icon
    DOMAIN=$(echo "$URL" | sed -E 's/^\s*.*:\/\///g' | cut -d'/' -f1)

    # Define a clean local directory for custom downloaded web icons
    ICON_DIR="$HOME/.local/share/icons/web_shortcuts"
    mkdir -p "$ICON_DIR"

    LOCAL_ICON="$ICON_DIR/$DOMAIN.png"

    # Download high-res favicon from secure API cache if it doesn't already exist locally
    if [ ! -f "$LOCAL_ICON" ]; then
        curl -s -L "https://www.google.com/s2/favicons?sz=64&domain=$DOMAIN" -o "$LOCAL_ICON"
    fi

    # Verify download succeeded and file has data; otherwise drop back to syncthing
    if [ -s "$LOCAL_ICON" ]; then
        ICON_ID="$LOCAL_ICON"
    else
        ICON_ID="syncthing"
    fi
fi

# Create the .desktop file using your original single-line layout
echo -e "[Desktop Entry]\nName=$NAME\nType=Link\nURL=$URL\nComment=\nTerminal=false\nIcon=$ICON_ID\nType=Link" > "$DEST/$NAME.desktop"

# Ensure correct file permissions
chmod 644 "$DEST/$NAME.desktop"

# Check if the file creation and permissions succeeded first
if [ $? -eq 0 ]; then
    # SUCCESS: Now apply the shortcut emblem metadata if it is an external web link
    if [ ! -d "$URL" ]; then
        gio set -t stringv "$DEST/$NAME.desktop" metadata::emblems emblem-symbolic-link
    fi

    notify-send --expire-time=200000 "Shortcut successfully created in $DEST"
    exit 0
else
    notify-send --expire-time=200000 "Error: Failed to create shortcut."
    exit 1
fi
