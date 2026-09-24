#!/usr/bin/env bash
# =============================================================
# Deploy do SYNUSD na Sepolia (testnet) + verificacao no Etherscan
# Pre-requisitos:
#   1) .env com PRIVATE_KEY, ADDRESS, SEPOLIA_RPC, ETHERSCAN_API_KEY
#   2) Saldo de Sepolia ETH na carteira (faucet)
# Uso: ./deploy-sepolia.sh
# =============================================================
set -euo pipefail
cd "$(dirname "$0")"

source .env 2>/dev/null || { echo "ERRO: crie o .env primeiro"; exit 1; }

if [ -z "${ETHERSCAN_API_KEY:-}" ]; then
  echo "ERRO: preencha ETHERSCAN_API_KEY no .env (crie gratis em https://etherscan.io/apis)"
  exit 1
fi

echo "== 1/4 Saldo da carteira =="
BAL=$(cast balance "$ADDRESS" --rpc-url "$SEPOLIA_RPC" --ether)
echo "  $ADDRESS => $BAL ETH"
if [ "$BAL" = "0.000000000000000000" ]; then
  echo "ERRO: carteira sem saldo. Pegue Sepolia ETH em um faucet:"
  echo "  - https://cloud.google.com/application/web3/faucet/ethereum/sepolia (login Google)"
  echo "  - https://www.alchemy.com/faucets/ethereum-sepolia (conta gratuita)"
  echo "  - https://faucets.chain.link/sepolia (login GitHub)"
  exit 1
fi

echo "== 2/4 Deploy (via cast — contorna bug MPP do forge create 1.8.x) =="
BYTECODE=$(jq -r '.bytecode.object' out/StablecoinPadraoTether.sol/StablecoinPadraoTether.json | sed 's/^0x//')
ARGS=$(cast abi-encode "constructor(uint256,string,string,uint8)" 0 "Synthetic Dollar" "SYNUSD" 6 | sed 's/^0x//')
INITCODE="0x${BYTECODE}${ARGS}"
cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC" --create "$INITCODE" 2>&1 | grep -E "contractAddress|^status"

echo ""
echo "== 3/4 Mint inicial (100 tokens p/ teste) =="
# COLE AQUI o endereco impresso acima:
TOKEN=${TOKEN:?export TOKEN=0x...antes_de_rodar}
cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC" "$TOKEN" "issue(uint256)" 100000000 2>&1 | grep -E "^status"

echo "== 4/4 Verificar source no Etherscan =="
forge verify-contract "$TOKEN" contracts/StablecoinPadraoTether.sol:StablecoinPadraoTether \
  --chain 11155111 --etherscan-api-key "$ETHERSCAN_API_KEY" --watch

echo "== Logo: https://sepolia.etherscan.io/token/$TOKEN → ⋮ → Update this token =="
