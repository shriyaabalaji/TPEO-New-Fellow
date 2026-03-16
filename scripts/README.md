# Scripts

## iOS: Keep your bundle ID after `git pull`

So you don’t have to fix signing every time you pull:

1. **One-time setup**
   - Copy `ios/LocalBundleId.txt.example` to `ios/LocalBundleId.txt`.
   - Edit `ios/LocalBundleId.txt` and put your bundle ID on the first line (e.g. `com.yourteam.tpeo.newfellow`). Use an ID that’s registered to your Apple team.
   - Run: `./scripts/install-git-hooks.sh`

2. **After that**  
   When you run `git pull`, the post-merge hook will apply your local bundle ID to the Xcode project so signing keeps working. You don’t need to do anything else.

`ios/LocalBundleId.txt` is gitignored, so your ID stays local and isn’t committed.
