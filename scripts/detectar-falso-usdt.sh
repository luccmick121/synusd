#!/usr/bin/env bash
# ============================================================================
# detectar-falso-usdt.sh — ferramenta de segurança para identificar clones
#
# USO:  ./scripts/detectar-falso-usdt.sh <endereco> [eth|bsc]
#
# Regra de ouro: o USDT é identificado pelo ENDEREÇO DO CONTRATO,
# nunca pelo nome/símbolo (que qualquer contrato pode copiar).
# ============================================================================
set -euo pipefail

# Endereços oficiais do USDT (fonte: tether.to/en/transparency e docs Binance)
OFICIAL_ETH="0xdac17f958d2ee523a2206206994597c13d831ec7"
OFICIAL_BSC="0x55d398326f99059fF775485246999027B3197955"

RPC_ETH="https://ethereum-rpc.publicnode.com"
RPC_BSC="https://bsc-rpc.publicnode.com"

END="${1:?USO: $0 <endereco> [eth|bsc]}"
REDE="${2:-eth}"

# normaliza para lowercase
END=$(echo "$END" | tr '[:upper:]' '[:lower:]')
OFICIAL_ETH_L=$(echo "$OFICIAL_ETH" | tr '[:upper:]' '[:lower:]')
OFICIAL_BSC_L=$(echo "$OFICIAL_BSC" | tr '[:upper:]' '[:lower:]')

case "$REDE" in
  eth) RPC="$RPC_ETH"; OFICIAL="$OFICIAL_ETH_L" ;;
  bsc) RPC="$RPC_BSC"; OFICIAL="$OFICIAL_BSC_L" ;;
  *) echo "rede invalida: use eth ou bsc"; exit 1 ;;
esac

echo "════════════════════════════════════════════════════"
echo " VERIFICACAO DE USDT — rede: $REDE"
echo "════════════════════════════════════════════════════"
echo " endereco consultado : $END"

# existe contrato nesse endereco?
SIZE=$(cast codesize "$END" --rpc-url "$RPC" 2>/dev/null || echo 0)
if [ "$SIZE" = "0" ] || [ -z "$SIZE" ]; then
  echo " contrato            : NAO EXISTE nesta rede (EOA ou vazio)"
  echo " VEREDITO            : ✗ nao e o USDT oficial"
  exit 2
fi
echo " contrato            : existe ($SIZE bytes de codigo)"

# le metadados declarados
NOME=$(cast call "$END" "name()(string)"   --rpc-url "$RPC" 2>/dev/null || echo "?")
SIMB=$(cast call "$END" "symbol()(string)" --rpc-url "$RPC" 2>/dev/null || echo "?")
DEC=$(cast call  "$END" "decimals()(uint8)" --rpc-url "$RPC" 2>/dev/null || echo "?")
echo " name() declarado    : $NOME"
echo " symbol() declarado  : $SIMB"
echo " decimals() declarado: $DEC"

# veredito por endereco
if [ "$END" = "$OFICIAL" ]; then
  echo " VEREDITO            : ✓ USDT OFICIAL (endereco bate com o oficial da $REDE)"
  exit 0
else
  echo " oficial da rede     : $OFICIAL"
  if [[ "$NOME" == *"Tether"* || "$SIMB" == *"USDT"* ]]; then
    echo " VEREDITO            : ✗ CLONE/FALSO USDT — declara ser Tether/USDT"
    echo "   >>> ALERTA: qualquer 'USDT' fora do endereco oficial e falsificado."
    echo "   >>> Nao aceitar em P2P/OTC. Conferir SEMPRE o endereco do contrato."
    exit 3
  else
    echo " VEREDITO            : ~ token comum (nao se declara USDT, mas tambem nao e o oficial)"
    exit 1
  fi
fi
