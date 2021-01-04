# MCAppleSilicon
Minecraft on Apple Silicon

This is a "neatly" packaged version of [Tanmay Bakshi's Gist](https://gist.github.com/tanmayb123/d55b16c493326945385e815453de411a).

In theory, this should bundle everything as a single `.app` that any layperson could download and double-click. The script included will download all of the assets needed, set up the username and password for the Minecraft user, and launch.

It works on my computer. It probably won't on yours, though, as there are various entitlements and Gatekeeper settings that may need to be adjusted.

## [Download](https://github.com/ohnx/MCAppleSilicon/archive/master.zip)

## faq

**Q: this doesn't work!**  
**A:** try adjusting your Gatekeeper settings (right click, then press "Open" then press "Trust" or something like that).

## how it works

* Download `zip` archive from Google Drive to `~/Library/Application Support/MCAppleSilicon`
* Run setup scripts
* Store username/password in Keychain because "security"
* Fetch username/password from Keychain
* Launch game

## todos

* Prompt user if they want to copy over existing minecraft save/settings/etc. data
* ??? probably more things if people actually end up using this
