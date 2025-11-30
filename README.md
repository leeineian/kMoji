<br />
<div align="center">
  <a href="https://github.com/ethncldemnts/emote.selector.plus">
    <img src="./icon.svg" alt="Logo" width="80" height="80">
  </a>

  <h1 align="center">Emote Selector Plus</h1>

  <p align="center">
    A panel-integrated emote selector for KDE Plasma 6.
    <br />
  </p>
</div>

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
