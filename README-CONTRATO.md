# Stablecoin Padrão Tether (USDT-like)

Contrato ERC-20 portado da arquitetura do **TetherToken (USDT)** verificado no Etherscan,
modernizado para Solidity 0.8.x, com comentários em português e testes Foundry.

---

## 1. Como o USDT real funciona (análise)

O USDT **não** é um ERC-20 "puro". Ele é um token **centralizado** com controles administrativos:

| Mecânica | Função | Efeito |
|---|---|---|
| Emissão | `issue(amount)` | Owner cria novos tokens (quando entra reserva) |
| Resgate | `redeem(amount)` | Owner queima tokens (quando sai reserva) |
| Pausa | `pause()` / `unpause()` | Congela TODAS as transferências |
| Blacklist | `addBlackList(addr)` | Endereço não pode enviar nem receber |
| Confisco | `destroyBlackFunds(addr)` | Queima TODO saldo de endereço na blacklist |
| Taxa | `setParams(bps, maxFee)` | Cobra até 0,20% por transferência (teto 50 tokens) |
| Upgrade | `deprecate(newAddr)` | Encaminha transferências para contrato novo via `*ByLegacy` |
| Posse | `transferOwnership` → `acceptOwnership` | Troca de dono em 2 passos (evita erro de digitação) |

### Papéis (no Tether real)
- **owner** — controla emissão, deprecate, destroyBlackFunds, setParams, pausa e blacklist
- **pauser / blacklister** — no contrato principal do Tether tudo converge para o owner;
  em versões da Binance/other chains existem papéis separados

### Detalhes que pegam quem copia sem ler
1. **Decimais = 6** (não 18!) — 100 USDT = `100000000`
2. Taxa de transferência vai para o **owner**
3. `transferFrom` checa blacklist de **remetente, destino e spender**
4. `deprecate` não é proxy delegatecall — as funções chamam o novo contrato por `transferByLegacy`
5. Após `approve` depreciado, chama `approveByLegacy` no contrato novo

---

## 2. Estrutura deste projeto

```
contracts/StablecoinPadraoTether.sol   # contrato principal
test/StablecoinPadraoTether.t.sol      # testes Foundry (cobrem todas as mecânicas)
README-CONTRATO.md                     # este arquivo
```

### Diferenças do porte vs original (0.4.17 + SafeMath)
- Solidity ^0.8.24 — overflow/underflow checado nativamente (SafeMath removido)
- Mensagens de erro explícitas em português
- NatSpec documentando cada mecânica
- Mesmos nomes de funções/eventos → compatível com integrações que esperam o padrão USDT

---

## 3. Como implantar

### Opção A — Remix (sem instalar nada)
1. Acesse https://remix.ethereum.org
2. Crie o arquivo `StablecoinPadraoTether.sol` e cole o código
3. Compile com `0.8.24+`
4. Deploy (rede de teste primeiro!) com argumentos do constructor:
   ```text
   _initialSupply: 0
   _name:          "Synthetic Dollar"
   _symbol:        "SYNUSD"
   _decimals:      6
   ```
5. Em seguida emita com `issue(1000000000)` (1.000 tokens)

### Opção B — Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge init . --force          # dentro da pasta do projeto
forge build
forge test -vvv               # roda os testes
forge create contracts/StablecoinPadraoTether.sol:StablecoinPadraoTether \
  --constructor-args 0 "Synthetic Dollar" "SYNUSD" 6 \
  --rpc-url $SEPOLIA_RPC --private-key $PK
```

---

## 4. Checklist pós-deploy

- [ ] Transferir posse para multisig (Gnosis Safe) — NUNCA deixar em EOA
- [ ] Emitir primeiro lote via `issue()` documentando a reserva correspondente
- [ ] Testar blacklist + unpause em testnet antes de mainnet
- [ ] Verificar o contrato no Etherscan (publish/verify source)
- [ ] Planejar auditoria antes de qualquer valor relevante

---

## 5. Avisos importantes (a parte "legítima" do negócio)

1. **O contrato é a parte fácil.** O que faz um stablecoin valer US$ 1 é a **reserva**
   (dólares, títulos) e a política de resgate — coisas que vivem **fora** da blockchain.
   Sem isso, é só um token com o nome bonito.
2. **Identidade própria obrigatória.** Não use nome/símbolo "Tether"/"USDT" — além de marca
   registrada, emitir token "parecido com USDT" para negociar é fraude. Use nome próprio
   (aqui usamos SYNUSD como exemplo).
3. **Centralização tem custo.** O padrão Tether dá ao owner poder de congelar e confiscar.
   Se o objetivo é um token mais descentralizado, avalie OpenZeppelin AccessControl
   com papéis separados e timelock.
4. **Compliance.** Emissor de stablecoin pode se enquadrar em regulação de serviços de
   pagamento/ativos digitais (no Brasil, BACEN/lei 14.478). Vale consultar advogado.
