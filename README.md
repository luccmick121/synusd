# Synthetic Dollar (SYNUSD)

Token ERC-20 de estudo seguindo a arquitetura do **Tether USD (USDT)** —
contrato compatível com Solidity 0.6.6 e 0.8.24, testado com Foundry.

## Contratos implantados (Sepolia testnet)

| Compilador | Endereço | Status |
|---|---|---|
| 0.8.24 | [`0x7784618bACe35927246313B72bC092C1F78b1Cd7`](https://sepolia.etherscan.io/token/0x7784618bACe35927246313B72bC092C1F78b1Cd7) | ✅ Verificado |
| 0.6.6 | [`0x1c0f4594a0ceda324da1c846ef7c6f19c1398e0c`](https://sepolia.etherscan.io/token/0x1c0f4594a0ceda324da1c846ef7c6f19c1398e0c) | ✅ Verificado |
| 0.6.6 (bug didático) | [`0x64f44A1472b08e03C7660CCf68599aC556EF4eBc`](https://sepolia.etherscan.io/token/0x64f44A1472b08e03C7660CCf68599aC556EF4eBc) | 🐛 Museu do bug uint8 |

## Arquitetura (padrão TetherToken)

- 6 decimais (como o USDT)
- Emissão/resgate centralizados: `issue()` / `redeem()`
- Pausa global, blacklist e confisco: `pause()`, `addBlackList()`, `destroyBlackFunds()`
- Taxa configurável: `setParams()` (basis points + teto)
- Migração: `deprecate()` + funções `*ByLegacy()`
- Posse em 2 passos: `transferOwnership()` → `acceptOwnership()`

## Testes

14/14 passando (`forge test`) — incluindo regressão do bug de overflow
uint8 em `10 ** decimals` (ver `test_SetParams_MaxFee_CalculadoCorretamente`).

## Documentação

- [`docs/ANALISE-USDT-REAL.md`](docs/ANALISE-USDT-REAL.md) — análise do USDT real com dados on-chain
- [`docs/LOGO-PIPELINE.md`](docs/LOGO-PIPELINE.md) — como logos funcionam por plataforma
- [`docs/LOGO-E-LIQUIDEZ.md`](docs/LOGO-E-LIQUIDEZ.md) — peg 1:1 e liquidez
- [`docs/DEPLOY-REGISTRO.md`](docs/DEPLOY-REGISTRO.md) — registro dos deploys

## Aviso

Projeto educacional em testnet. Não é afiliado à Tether. Token próprio com
identidade própria (`assets/logo.png`).
