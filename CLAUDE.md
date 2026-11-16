# Project rules

- **Always ship, never keep code local**: after finishing any change in this project, immediately commit and push to `origin main`. End every task with a clean working tree and nothing unpushed (`git status -sb` shows `## main...origin/main`).
- **Remote**: `git@github-leowilbur:leowilbur/learning-words.git` (private, GitHub account `leowilbur`, pushed over the `github-leowilbur` SSH host alias). The `gh` CLI on this machine is logged into a different account and cannot read this repo; check Actions runs and Releases through the user's open Chrome instead.
- **Build**: every push to `main` that touches non-Markdown files runs `.github/workflows/build-ipa.yml`, which publishes an unsigned `LearningWords.ipa` as release `v1.<run number>`; the app's own version (`MARKETING_VERSION`) is set to the same `1.<run number>`, so never bump the version by hand. After pushing, wait for the run and report the release link.
- **No local toolchain**: this is a Linux machine without Xcode, so the CI build is the only compile check. Nothing can be run on a device or simulator from here.
