# Android SDK Tools (macOS only)
export ANDROID_HOME="$HOME/Library/Android/sdk"

if [ -d "$ANDROID_HOME" ]; then
    [ -d "$ANDROID_HOME/emulator" ] && export PATH=$PATH:$ANDROID_HOME/emulator
    [ -d "$ANDROID_HOME/platform-tools" ] && export PATH=$PATH:$ANDROID_HOME/platform-tools
fi
