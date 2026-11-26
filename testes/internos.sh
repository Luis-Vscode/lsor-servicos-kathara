#!/bin/sh
# Executa no no admin (LAN: 10.10.2.10)
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "[OK]     $1 - $2"; }
fail() { FAIL=$((FAIL+1)); echo "[FALHOU] $1 - $2"; }

# T1: HTTP 200 e pagina da dupla
T1_OUT=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/ 2>&1)
T1_CODE=$(echo "$T1_OUT" | tail -n1)
if [ "$T1_CODE" = "200" ] && echo "$T1_OUT" | grep -q "Agatha" && echo "$T1_OUT" | grep -qi "Gustavo"; then
  ok "T1" "HTTP 200 e pagina inicial contem os nomes da dupla"
else
  fail "T1" "esperado HTTP 200 com nomes da dupla (obtido HTTP $T1_CODE)"
fi

# T2: /api/status retorna JSON
T2_OUT=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/api/status 2>&1)
T2_CODE=$(echo "$T2_OUT" | tail -n1)
if [ "$T2_CODE" = "200" ] && echo "$T2_OUT" | grep -q '"status":"ok"'; then
  ok "T2" "HTTP 200 e JSON de status valido em /api/status"
else
  fail "T2" "esperado HTTP 200 com JSON de status (obtido HTTP $T2_CODE)"
fi

# T3: caminho inexistente retorna 404 personalizado
T3_OUT=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/rota-inexistente 2>&1)
T3_CODE=$(echo "$T3_OUT" | tail -n1)
if [ "$T3_CODE" = "404" ] && echo "$T3_OUT" | grep -qi "lsor-web"; then
  ok "T3" "HTTP 404 com pagina personalizada"
else
  fail "T3" "esperado HTTP 404 personalizado (obtido HTTP $T3_CODE)"
fi

# T4: SSH com chave publica retorna hostname bastion sem senha
T4_OUT=$(ssh -i /root/.ssh/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 dupla@10.10.1.22 hostname 2>/dev/null)
if [ "$T4_OUT" = "bastion" ]; then
  ok "T4" "SSH por chave publica autenticou e retornou 'bastion'"
else
  fail "T4" "esperado 'bastion' via SSH por chave (obtido: '$T4_OUT')"
fi

# T5: SSH sem chave publica deve ser recusado (Permission denied (publickey))
T5_OUT=$(ssh -o PubkeyAuthentication=no -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 dupla@10.10.1.22 hostname 2>&1)
T5_RC=$?
if [ "$T5_RC" -ne 0 ] && echo "$T5_OUT" | grep -qi "Permission denied (publickey)"; then
  ok "T5" "SSH sem chave recusado com Permission denied (publickey)"
else
  fail "T5" "esperado Permission denied (publickey) (rc=$T5_RC, saida: $T5_OUT)"
fi

echo "--- Resumo internos: $PASS OK, $FAIL FALHOU ---"
[ "$FAIL" -eq 0 ]
