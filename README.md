# <img src="./assets/icon.svg" height="30" vertical-align="middle" alt="logo"/> Emote Selector Plus

A panel-integrated emote selector for Plasma 6.

## Install/Update

```fish
# Install or update the plasmoid from this folder
kpackagetool6 -t Plasma/Applet -i ~/PATH/TO/emote.selector.plus
# If already installed, use -u to update
kpackagetool6 -t Plasma/Applet -u ~/PATH/TO/emote.selector.plus
```

## Run in a window

```fish
plasmawindowed emote.selector.plus
```

## Notes
- Requires Plasma 6 (KF6) and Qt 6.
- Clipboard uses KDE KQuickControlsAddons. Ensure the `org.kde.kquickcontrolsaddons` QML module is present.
- Emoji data is loaded from `assets/emoji-list.js`

## Updating Emoji Data

To update the emoji list:
You can use either the Python script or the Bash script.

Make sure the script is executable (once):
```fish
chmod +x contents/service/update_emoji.sh
```
Then run:
```fish
contents/service/update_emoji.sh
```

### Sync Status Markers
During sync the script writes markers to the log file the UI polls:
- `SYNC_STARTED` – Sync began.
- `SYNC_NET_ERROR` – Network failure downloading the Unicode test file.
- `SYNC_COMPLETE` – Successful completion.

### Checksum
The generated `emoji-list.js` header includes a `SHA256` line for the source `emoji-test.txt`. The raw `emoji-test.txt` is deleted after a successful sync.
