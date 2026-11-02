#!/usr/bin/env bash
# Yalnızca DEBUG derlemesinde: çentiği komutla tetikler (görsel test / ekran görüntüsü için).
# Kullanım: scripts/debug-notch.sh toggle|toggleall|shelf|settings|hud|charge|device|airpods|download|music|next|timer|cal|done|clear|peek|half|rest
set -euo pipefail
CMD="${1:?komut: toggle|toggleall|shelf|settings|hud|charge|device|airpods|download|music|next|timer|cal|done|clear|peek|half|rest}"
swift - "$CMD" <<'EOF'
import Foundation
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.ismsahin.Burrow.debug"), object: CommandLine.arguments[1], userInfo: nil, deliverImmediately: true)
EOF
