# Android SDK tools path detection (macOS + Linux).
# Prefer user-provided values, then probe common install paths.

_android_sdk_dir=""

if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    _android_sdk_dir="$ANDROID_HOME"
elif [ -n "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
    _android_sdk_dir="$ANDROID_SDK_ROOT"
elif [ -d "$HOME/Library/Android/Sdk" ]; then
    _android_sdk_dir="$HOME/Library/Android/Sdk"
elif [ -d "$HOME/Library/Android/sdk" ]; then
    _android_sdk_dir="$HOME/Library/Android/sdk"
elif [ -d "$HOME/Android/Sdk" ]; then
    _android_sdk_dir="$HOME/Android/Sdk"
fi

if [ -n "$_android_sdk_dir" ]; then
    export ANDROID_HOME="$_android_sdk_dir"
    export ANDROID_SDK_ROOT="$_android_sdk_dir"

    case ":$PATH:" in
        *":$ANDROID_HOME/emulator:"*) ;;
        *) [ -d "$ANDROID_HOME/emulator" ] && export PATH="$PATH:$ANDROID_HOME/emulator" ;;
    esac

    case ":$PATH:" in
        *":$ANDROID_HOME/platform-tools:"*) ;;
        *) [ -d "$ANDROID_HOME/platform-tools" ] && export PATH="$PATH:$ANDROID_HOME/platform-tools" ;;
    esac
fi

unset _android_sdk_dir
