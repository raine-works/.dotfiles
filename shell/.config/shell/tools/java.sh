# Java — Zulu 11 JDK
[ -d "/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home" ] || return 0

export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
