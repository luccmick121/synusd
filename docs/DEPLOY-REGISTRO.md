# REGISTRO DE DEPLOY — Sepolia (testnet)

## Tokens SYNUSD implantados (comparativo de compiladores)

| # | Endereço | Compilador | Status | Nota |
|---|---|---|---|---|
| 1 | `0x7784618bACe35927246313B72bC092C1F78b1Cd7` | 0.8.24 | ✅ Verificado, 100 SYNUSD | Deploy gas: 3.171.901 |
| 2 | `0x64f44A1472b08e03C7660CCf68599aC556EF4eBc` | 0.6.6 | ⚠️ **BUGADA — museu do bug** | `maximumFee=640` (overflow uint8) |
| 3 | `0x1c0f4594a0ceda324da1c846ef7c6f19c1398e0c` | 0.6.6 | ✅ Verificado, 100 SYNUSD, params OK | Deploy gas: 1.682.476 |

## O bug documentado (contrato #2 — mantido vivo de propósito)

Em Solidity < 0.8, `10 ** decimals` com `decimals` uint8 calcula em uint8:
```
10 ** 6  →  1.000.000 mod 256  =  64      (overflow silencioso, sem revert)
setParams(10, 10)  →  maximumFee = 10 × 64 = 640   (esperado: 10.000.000)
```
Prova on-chain: `cast call 0x64f4...4eBc "maximumFee()(uint256)"` → 640
Correção (idêntica à do Tether real, `uint(10)**decimals`):
`uint256(10) ** decimals` — aplicada e coberta por teste de regressão
(`test_SetParams_MaxFee_CalculadoCorretamente`).

## Comparativo de gas medido (mesmo ambiente, anvil local)

| Operação | 0.6.6 | 0.8.24 | Diferença |
|---|---|---|---|
| Deploy (local) | 1.682.464 | 1.633.769 | 0.8.24 ~3% mais barato |
| issue | 69.090 | 69.291 | +0,3% |
| transfer | 62.412 | 62.895 | +0,8% |
| transfer+taxa | 49.677 | 50.240 | +1,1% |
| setParams | 71.593 | 72.079 | +0,7% |
| Runtime size | 6.999 B | 6.753 B | 0.8.24 menor |

*Nota: o deploy 0.8.24 na Sepolia (#1) registrou 3,17M gas — anomalia vs 1,63M
local; atribuída ao estado de build da época (múltiplos rebuilds entre perfis).
A comparação confiável é a local, em condições idênticas.*

## Carteiras e chaves
- Deployer (descartável, testnet-only): `0xaF8Df0bc1bb814C40c15FFf54bF842dca073b9a1`
- Chave: em `.env` (NUNCA usar em mainnet)

## Links úteis
- Token #1: https://sepolia.etherscan.io/token/0x7784618bACe35927246313B72bC092C1F78b1Cd7
- Token #3: https://sepolia.etherscan.io/token/0x1c0f4594a0ceda324da1c846ef7c6f19c1398e0c
- Bug #2: https://sepolia.etherscan.io/token/0x64f44A1472b08e03C7660CCf68599aC556EF4eBc

## Fluxo técnico validado nesta sessão
- `forge create` 1.8.3 quebra (MPP) → deploy via `cast send --create <initcode>`
- forge-std 1.16.2 exige solc ≥0.8.13 → testes no perfil default 0.8.24
- Perfil `sol066` (skip test) gera artefato 0.6.6 para deploy/verify
- Verify: `forge verify-contract --profile sol066` (usa compilador certo)
