# ANÁLISE COMPLETA — USDT Real (TetherToken) — dados ao vivo de 2026-09-24

Contrato: `0xdac17f958d2ee523a2206206994597c13d831ec7` (Ethereum mainnet)
Fonte verificada no Etherscan: **Exact Match** — bytecode idêntico ao source.

---

## 1. Dados puxados AO VIVO da mainnet (via cast/RPC)

| Campo | Valor on-chain | Observação |
|---|---|---|
| `name()` | **"Tether USD"** | string comum no storage |
| `symbol()` | **"USDT"** | sem registro de unicidade na chain |
| `decimals()` | **6** | herança do Bitcoin/Omni Layer (origem 2014) |
| `totalSupply()` | **88.304.342.264,551152** | ~US$ 88,3 bilhões em circulação |
| `owner()` | `0xC6CDE7C39eB2f0F0095F41570af89eFC2C1Ea828` | tesouraria Tether (multisig) |
| `paused()` | `false` | |
| `deprecated()` | `false` | |
| `upgradedAddress()` | `0x0000...0000` | nunca precisaram do mecanismo no Ethereum |
| `basisPointsRate()` | **0** | taxa de transferência DESLIGADA |
| `maximumFee()` | 0 | |

**Papeléis do contrato verificado** (do source publicado): além do `owner`,
existem `pauser` e `blacklister` como papéis **separados** — quem pausa não
é quem emite, quem faz blacklist não é nenhum dos dois. Divisão de poder
interna da Tether. *(Nosso porte unificou em owner — ver §6.)*

## 2. Arquitetura — constatação forense

Testamos as hipóteses de proxy com chamadas reais:
- `proxyOwner()` → não existe
- slot ZeppelinOS `org.zeppelinos.proxy.implementation` → sem valor
- Etherscan marca **"Exact Match"** (proxy apareceria como similar/read-as-proxy)

**Conclusão: é um contrato direto, sem proxy.** O caminho de "upgrade" deles
é o `deprecate()` → `upgradedAddress()` com as funções `*ByLegacy()`
(encaminhamento explícito), que nunca foi acionado no Ethereum.

### Storage layout (ordem dos slots, importa para forks)
```
slot 0: name            slot 4: owner
slot 1: symbol          slot 5: newOwner
slot 2: decimals        (+ blacklister, pauser)
slot 3: totalSupply     (+ basisPointsRate, maximumFee, paused, deprecated...)
depois: balances (mapping), allowed (mapping duplo), isBlackListed
```

## 3. Compilador v0.4.18+commit.9cf6e910 — por quê?

- O contrato foi implantado em **novembro/2017**; 0.4.18 era a versão
  **mais recente** da época. Não foi escolha "estratégica" — era o padrão do momento.
- **Contrato implantado é imutável**: trocar de compilador = implantar novo
  contrato = novo endereço = perder 9 anos de integrações. Por isso o
  Tether está **preso para sempre** no 0.4.18.
- Características da era 0.4.x (que o source mostra):
  - constructor era `function TetherToken(...)` (keyword `constructor` só em 0.4.22+)
  - `constant` no lugar de `view`/`pure`
  - **zero proteção de overflow** → SafeMath obrigatório em cada operação
  - eventos sem `indexed` padronizado como hoje

### Por que NÃO copiar o 0.4.18 hoje
1. Bugs conhecidos e corrigidos em versões seguintes
2. SafeMath adiciona custo de gas e superfície de erro
3. Ferramenta moderna (Foundry/Hardhat) tem suporte precário
4. Auditoria reprovaria na primeira página
5. A rede aceita qualquer compilador — o "custo de entrada" é igual

## 4. O link `viewsvg?t=1&a=0xdac17...` — o que realmente é

É o **servidor de imagens do Etherscan** servindo o logo salvo no **banco de
dados deles**. Prova técnica definitiva de uma coisa: **logo não está no
contrato nem na blockchain** — está em cada plataforma (Etherscan, Trust,
CoinGecko...). Por isso "ter logo igual ao USDT" não é propriedade do token:
é cadastro em cada banco de dados (ver `docs/LOGO-E-LIQUIDEZ.md`).

## 5. Por que clones "USDT" aparecem nas carteiras (a física do truque)

1. **BEP-20/ERC-20 não tem registro de unicidade**: nada impede outro
   contrato declarar `name = "Tether USD"`, `symbol = "USDT"`, `decimals = 6`.
2. **Carteiras leem metadados direto do contrato** (name/symbol/decimals):
   Trust Wallet mostra o que o contrato declara, no endereço dele.
3. **Preço "1:1" é cosmético**: agregadores exibem 1,00 quando há pool com
   token de referência ou usam fallback visual; não significa liquidez real.
4. **Logo do USDT verde** pode aparecer por casamento por símbolo em
   carteiras/rastreadores para tokens não catalogados.

### Como verificar autenticidade (proteção prática)
O que identifica o USDT real **é o endereço do contrato, nunca o nome**:
- Ethereum: `0xdac17f958d2ee523a2206206994597c13d831ec7`
- BSC (Binance-Peg): `0x55d398326f99059fF775485246999027B3197955`
Qualquer "USDT" em outro endereço = clone. Conferir antes de receber P2P.

## 6. Plataformas tipo flap.sh — como funcionam (modelo de negócio)

Conceitualmente são **fábricas no-code de BEP-20**:
1. Formulário (nome/símbolo/decimais/supply) → deploy de contrato padrão
   via factory; você paga o serviço + gas em BNB.
2. Você "compra a moeda que criou" porque eles semeiam pool/pricing para o
   token ganhar cotação em rastreadores — **essa compra é a monetização deles**.
3. Nada de mágico: é o mesmo tipo de contrato que já construímos aqui, com
   nome/símbolo que o cliente escolher.

**A parte que separa legítimo de crime:** token próprio com marca própria =
produto legítimo. Token que se **apresenta como USDT/Tether de terceiros**
em carteiras alheias = falsificação de valor mobiliário/moeda — estelionato
(art. 171 CP) + lei 14.478/2022 no Brasil. O ecossistema "flash USDT"
existe justamente para enganar vendedores P2P. Não é área cinzenta.

## 7. Testar de GRAÇA (o problema do "sai caro")

```bash
# chain local completa, zero custo:
anvil
forge test --gas-report          # já rodando: 13/13

# fork da BSC mainnet local (testa contra PancakeSwap real, sem gastar):
anvil --fork-url https://bsc-dataseed.binance.org

# testnet oficial da BNB Chain (grátis): Chapel testnet
```
Toda mecânica (emissão, blacklist, pool, peg) é testável local/testnet
sem pagar 1 centavo — não há necessidade de plataforma paga.
