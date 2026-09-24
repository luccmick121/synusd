# PIPELINE DE LOGO — por que "não vai" e como fazer aparecer de verdade

> Resposta direta ao problema: "todo token que a gente cria, a logo não aparece".

---

## 1. A causa raiz (o que ninguém explica)

**Logo não é propriedade do token.** O contrato só carrega `name`, `symbol`,
`decimals` — texto puro. A imagem vive **no banco de dados de cada plataforma**:

```
Contrato (on-chain)  →  name / symbol / decimals        (só texto)
Etherscan            →  logo no DB deles               (formulário)
Trust Wallet         →  logo no repo trustwallet/assets (PR no GitHub)
MetaMask             →  logo via listas (CoinGecko etc.) (cadastro em cascata)
DEXScreener/GeckoTerminal → logo do CoinGecko/CMC        (cadastro em cascata)
```

Você deployou o token → carteira mostra **texto + primeira letra num círculo**.
Sem cadastro, é isso. Sempre foi isso.

### O detalhe do "USDT falso com logo verde"
Alguns wallets e rastreadores têm **heurística de casamento por símbolo**:
token desconhecido com símbolo popular (`USDT`) → mostra a logo do símbolo.
É isso que faz clones "ganharem" a logo verde **sem cadastrar nada** — e é
heurística de exibição, não recurso controlável (nem legítimo de se explorar).

---

## 2. O pipeline correto (ordem importa)

### Passo 0 — Deploy em testnet + verificação (pré-requisito de tudo)
```bash
# Sepolia (Ethereum) ou Chapel (BSC) — grátis
forge create contracts/StablecoinPadraoTether.sol:StablecoinPadraoTether \
  --constructor-args 0 "Synthetic Dollar" "SYNUSD" 6 \
  --rpc-url $SEPOLIA_RPC --private-key $PK \
  --verify --etherscan-api-key $ETHERSCAN_KEY
```
Sem `--verify`, nenhuma plataforma aceita cadastro de logo.

### Passo 1 — Etherscan (o cadastro-mãe)
1. Abra a página do token no explorer (ex.: sepolia.etherscan.io/token/0xSEU)
2. Menu ⋮ → **"Update this token"** (Token Update Request)
3. Preenha: site do projeto, logo (PNG 512×512, fundo transparente, **< 100 KB**),
   redes sociais, contato, descrição
4. Revisão humana: testnet costuma aprovar em dias; mainnet exige site ativo
   e presença real do projeto

### Passo 2 — Trust Wallet (PR público no GitHub)
1. Fork `github.com/trustwallet/assets`
2. Adicione `assets/blockchain/<rede>/<endereco-em-minusculo>.png`
   - nome do arquivo = **endereço do contrato em minúsculas**
   - PNG 512×512, transparente, < 100 KB
3. Abra o Pull Request → aprovação da comunidade → logo aparece no app

### Passo 3 — CoinGecko + CoinMarketCap
- Forms de listagem dos dois sites (exigem liquidez/pool ativa + site)
- **Efeito cascata**: MetaMask e dezenas de apps consomem essas bases
  — seu token ganha logo em vários lugares de uma vez

### Passo 4 — Uniswap/DEX (token list própria)
- Crie JSON de token list, hospede (GitHub Pages), submeta às listas públicas

---

## 3. Especificações do arquivo (rejeição mais comum = arquivo errado)

| Item | Valor |
|---|---|
| Formato | PNG (aceitam também, mas PNG é universal) |
| Tamanho | **512×512 px** |
| Fundo | **Transparente** (sem quadrado branco atrás) |
| Peso | **< 100 KB** (Etherscan reprova acima) |
| Nome do arquivo (Trust) | endereço do contrato, minúsculo, `.png` |

Assets deste projeto: `assets/logo.svg` (vetor editável) e `assets/logo.png`
(512×512 gerado do SVG — use este nos cadastros).

---

## 4. Identidade visual — a regra de ouro

Logo que você **não criou / não tem direito** = não usar (marca registrada +
confusão visual com token de terceiro = problema legal e moral).
Paleta, símbolo e estilo próprios = cadastro em qualquer plataforma sem risco.
A logo deste projeto (S com setas de emissão/resgate, indigo/ciano) é
deliberadamente distinta de qualquer stablecoin existente — inclusive de cor.
