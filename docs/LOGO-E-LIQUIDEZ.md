# Logo da Moeda + Liquidez 1:1 — Guia Completo

> Como fazer o token aparecer com logo nas carteiras/exploradores
> e como funciona o mecanismo de paridade (peg) com o dólar.

---

## PARTE 1 — LOGO: onde a imagem realmente mora

### A verdade técnica
O logo **não fica no contrato** (ERC-20 não tem campo de imagem). Cada
plataforma mantém seu próprio banco de imagens e você precisa cadastrar
o token em cada uma delas:

| Plataforma | Como o logo aparece | Onde cadastrar |
|---|---|---|
| **Etherscan** | Formulário de atualização de token | etherscan.io → menu do token → "Update" |
| **MetaMask** | Consome listas (CoinGecko, listas da comunidade) | Cadastre no CoinGecko |
| **Trust Wallet** | Repo público de assets | github.com/trustwallet/assets → PR |
| **Uniswap** | Token Lists (JSON assinado) | Criar sua própria token list + submeter às listas |
| **CoinGecko / CMC** | Cadastro do projeto | forms dos dois sites |
| **DEXScreener etc.** | Automático via pool + CGecko | Aparece quando cria liquidez |

### Especificações do arquivo de logo (padrão de mercado)
- **PNG**, fundo transparente
- **512×512 px** (algumas aceitam até 2000×2000)
- **< 100 KB** (Etherscan costuma rejeitar acima disso)
- Nome do arquivo: endereço do contrato em lowercase `.png`
  (ex.: `0xa0b1...c3d4.png`) para Trust Wallet assets

### Pré-requisitos que o Etherscan exige (senão ele reprova)
1. Contrato **verificado** (source publicado — `forge verify-contract`)
2. **Site oficial** do projeto com domínio próprio
3. Perfis sociais ativos (X/Twitter, GitHub, Telegram/Discord)
4. Descrição clara do projeto + info de contato
5. Liquidez em DEX (token sem pool tende a ser recusado)

### Ordem recomendada de cadastro
```
1. Verificar contrato no Etherscan      (sem isso nada acontece)
2. Criar pool de liquidez               (Parte 2 abaixo)
3. Formulário Etherscan (logo + links)
4. Trust Wallet assets (PR no GitHub)
5. CoinGecko + CoinMarketCap            (alimenta MetaMask e cia.)
6. Token List própria (Uniswap)         (JSON + deploy no GitHub Pages)
```

---

## PARTE 2 — LIQUIDEZ E O PEG 1:1

### Por que o preço "aparece" nos sites
Etherscan/DEXScreener/CGecko **não** inventam preço: eles leem o último
trade em pools de DEX. Sem pool = sem preço = token invisível.

### Como o 1:1 se sustenta (a física do peg)

O preço fica em 1,00 **por arbitragem contra resgate real**:

```
Preço cai p/ 0,97  →  árbitro compra barato no DEX e resgata 1,00 com você  → preço sobe
Preço sobe p/ 1,03 →  árbitro emite 1,00 com você e vende caro no DEX       → preço desce
```

Isso **só funciona** se existir:
1. **Emissão/resgate funcional** (nosso contrato tem: `issue()` / `redeem()`)
2. **Reserva real** de 1 dólar (ou USDC) para cada token emitido
3. **Liquidez suficiente** para o arbitragem valer a pena (cobrir gas + spread)

### Onde criar a pool

| Opção | Quando usar | Prós/Contras |
|---|---|---|
| **Uniswap V3 (range apertado)** | Começar com pouco capital | Range 0,99–1,01 concentra 100% do capital na zona do peg — MUITO eficiente, mas exige gestão do range |
| **Uniswap V2 (50/50)** | Liquidez simples/permanente | Fácil, mas espalha capital de 0 a ∞ — precisa muito mais $ para segurar o peg |
| **Curve (StableSwap)** | O padrão de mercado p/ stablecoins | Amplificador mantém preço quase plano perto de 1 — é onde USDT/USDC/DAI negociam. Exige metapool via factory |

### Receita prática de bootstrap (fase 1, Uniswap V3)

```
1. Mintar 100.000 SYNUSD            (issue — só com reserva equivalente!)
2. Separar 100.000 USDC              (ou USDT)
3. Criar pool V3 fee=0,05% (o tier de stablecoins)
4. Range: 0,995 – 1,005 USD          (capital todo concentrado no peg)
5. Minerar/estimular volume          (incentivos de recompensa se precisar)
6. Cadastros da Parte 1 (logo etc.)
```

Com range de ±0,5%, cada dólar de liquidez "trabalha" ~10x mais que
no V2 para segurar o preço perto de 1.

### A curva de valor (a parte que ninguém conta)
- Pool de $10k: um trade de $5k desloca o preço — peg vira piada
- Pool de $100k+: trades pequenos não mexem no preço
- Peg blindado: **resgate real + arbitragem automático** (bot próprio
  ou tolerância a quebras de ~0,3%)

### ⚠️ A regra de ouro da legitimidade
`issue()` **só** quando entra reserva; `redeem()` **sempre** que for pedido
com o token em mãos. Emitir sem reserva = o token quebra o peg na primeira
pressão e vira passivo legal. É exatamente a diferença entre um stablecoin
e um "token com nome de stablecoin".

---

## PARTE 3 — Checklist de lançamento (resumo)

- [ ] `forge build && forge test` — 13/13 passando ✔ (já está)
- [ ] Deploy em **Sepolia** (testnet) primeiro
- [ ] Verificar source no Etherscan (`forge verify-contract`)
- [ ] Transferir `owner` para **multisig** (Safe)
- [ ] Mint inicial = reserva comprovável 1:1
- [ ] Pool Uniswap V3 0,05% com range 0,995–1,005
- [ ] Logo 512×512 PNG < 100KB
- [ ] Formulário Etherscan + site + sociais
- [ ] Trust Wallet assets PR
- [ ] CoinGecko / CMC
- [ ] Plano de resgate documentado e público
