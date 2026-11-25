#!/bin/bash
# Log THIS machine into the campus internet portal (same method as the lab's l.py).
# Run it when downloads hang:  bash ~/portal_login.sh   (asks for your password; nothing is stored)
URL="https://10.240.240.1:6081/php/uid.php?vsys=1&rule=0"
if curl -s -m 8 -o /dev/null https://github.com; then echo "Internet already works."; exit 0; fi
read -rp "Campus username: " U
read -rsp "Campus password: " P; echo
J=$(mktemp); H=$(mktemp)
curl -sk -m 10 -c "$J" -b "$J" "$URL" -o "$H"
v() { grep -aoE "name=\"$1\" value=\"[^\"]*\"" "$H" | head -1 | sed -E 's/.*value="([^"]*)"/\1/'; }
curl -sk -m 15 -c "$J" -b "$J" -X POST "$URL" \
  --data-urlencode "inputStr=$(v inputStr)" --data-urlencode "escapeUser=$(v escapeUser)" \
  --data-urlencode "preauthid=$(v preauthid)" --data-urlencode "user=$U" --data-urlencode "passwd=$P" \
  --data-urlencode "ok=Login" -o "$H"
grep -aoE 'var respMsg = "[^"]+"' "$H" | cut -d'"' -f2
rm -f "$J" "$H"; unset P
sleep 3
curl -s -m 10 -o /dev/null https://github.com && echo "OK: internet works now." || echo "FAIL: still no internet (wrong username/password?)"
