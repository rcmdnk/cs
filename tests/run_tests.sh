#!/usr/bin/env bash
# Run the tests with bash and zsh.

cd "$(dirname "$0")" || exit 1
ret=0
shells="bash zsh"
# The system bash of macOS is 3.2: test it too when another bash comes first in PATH
if [ -x /bin/bash ] && [ "$(command -v bash)" != /bin/bash ];then
  shells="$shells /bin/bash"
fi
for sh in $shells;do
  if ! type "$sh" >/dev/null 2>&1;then
    echo "=== $sh: skipped (not installed) ==="
    continue
  fi
  echo "=== $sh ==="
  if "$sh" ../etc/cs > /dev/null 2>&1;then
    echo "  NG: etc/cs must refuse to be executed"
    ret=$((ret + 1))
  else
    echo "  ok: etc/cs refuses to be executed"
  fi
  "$sh" ./test.sh
  ret=$((ret + $?))
done
if [ "$ret" -eq 0 ];then
  echo "=== All tests passed ==="
else
  echo "=== $ret test(s) failed ==="
fi
exit "$ret"
