#!/bin/sh
# Executa no no ext (Internet: 203.0.113.50)
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "[OK]     $1 - $2"; }
fail() { FAIL=$((FAIL+1)); echo "[FALHOU] $1 - $2"; }

# T6: HTTP externo via DNAT no IP publico do gw
T6_OUT=$(curl -sS -w "\n%{http_code}" http://203.0.113.1/ 2>&1)
T6_CODE=$(echo "$T6_OUT" | tail -n1)
if [ "$T6_CODE" = "200" ] && echo "$T6_OUT" | grep -q "Agatha" && echo "$T6_OUT" | grep -qi "Gustavo"; then
  ok "T6" "HTTP 200 via DNAT em http://203.0.113.1/ com pagina da dupla"
else
  fail "T6" "esperado HTTP 200 via DNAT (obtido HTTP $T6_CODE)"
fi

# T7: SSH externo na porta 2222 -> bastion:22
T7_OUT=$(ssh -p 2222 -i /root/.ssh/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 dupla@203.0.113.1 hostname 2>/dev/null)
if [ "$T7_OUT" = "bastion" ]; then
  ok "T7" "SSH na porta 2222 via DNAT retornou 'bastion'"
else
  fail "T7" "esperado 'bastion' via SSH porta 2222 (obtido: '$T7_OUT')"
fi

# T8: NMAP externo - apenas 80 e 2222 abertas
T8_OUT=$(nmap -Pn -p- --min-rate 2000 203.0.113.1 2>&1)
OPEN_PORTS=$(echo "$T8_OUT" | awk '/^[0-9]+\/tcp[[:space:]]+open/{print $1}' | sort | tr '\n' ' ' | sed 's/[[:space:]]*$//')
if [ "$OPEN_PORTS" = "2222/tcp 80/tcp" ]; then
  ok "T8" "NMAP confirmou apenas as portas 80/tcp e 2222/tcp abertas"
else
  fail "T8" "portas abertas inesperadas: '$OPEN_PORTS'"
fi

# T9: ping para IP privado na DMZ deve falhar
if ping -c 2 -W 2 10.10.1.80 >/dev/null 2>&1; then
  fail "T9" "IP privado 10.10.1.80 respondeu ao ping da Internet"
else
  ok "T9" "IP privado 10.10.1.80 inacessivel a partir da Internet"
fi

echo "--- Resumo externos: $PASS OK, $FAIL FALHOU ---"
[ "$FAIL" -eq 0 ]
