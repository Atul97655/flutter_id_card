#!/usr/bin/env bash
# The Firestore emulator sometimes leaves its rules runtime holding a port
# after a run (a known NPE on shutdown). Free them before starting.
for p in 8080 9199 4400 4500 9150; do
  pid=$(netstat -ano 2>/dev/null | grep LISTENING | grep ":$p " | awk '{print $NF}' | head -1)
  [ -n "$pid" ] && taskkill //PID "$pid" //F >/dev/null 2>&1 && echo "freed port $p (pid $pid)"
done
exit 0
