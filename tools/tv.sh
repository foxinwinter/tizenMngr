#!/bin/bash
# tv.sh — run a command on the TV via the widget exec endpoint.
#
# Usage:
#   TV_IP=192.168.1.145 ./tv.sh '<shell-command>'
#   ./tv.sh '<shell-command>'          # uses $TV_IP
#
# Prereqs on the research host: python3, curl.
# The TV must have the widget service (kdbuswgt01) installed and running;
# it exposes the exec endpoint on port 7778.

set -euo pipefail

TV_IP="${TV_IP:?set TV_IP to the TV address (e.g. TV_IP=192.168.1.145)}"
PORT="${TV_PORT:-7778}"

cmd="$1"
python3 - "$cmd" "$TV_IP" "$PORT" <<'PYEOF'
import json, subprocess, sys, urllib.parse

cmd, ip, port = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"http://{ip}:{port}/exec?cmd=" + urllib.parse.quote(cmd, safe="")
try:
    out = subprocess.run(
        ["curl", "-s", "--max-time", "30", url],
        capture_output=True, text=True,
    )
    d = json.loads(out.stdout)
    print(d.get("stdout", "") or d.get("stderr", "") or "<no output>")
except Exception as e:
    print("ERR", e)
PYEOF
