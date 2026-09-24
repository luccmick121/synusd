// Teste do encoder JS contra o padrao de referencia (cast abi-encode)
// Rodar: node panel/test-encoder.mjs
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { encodeConstructorArgs } = require("./encoder.js");

const cases = [
  { supply: 0n, name: "Synthetic Dollar", symbol: "SYNUSD", decimals: 6 },
  { supply: 1000000n, name: "Meu Token", symbol: "MTK", decimals: 18 },
  { supply: 42n, name: "A", symbol: "B", decimals: 0 },
];

let ok = true;
for (const c of cases) {
  const mine = "0x" + encodeConstructorArgs(c);
  const ref = execSync(
    `cast abi-encode "constructor(uint256,string,string,uint8)" ${c.supply} "${c.name}" "${c.symbol}" ${c.decimals}`,
    { env: { ...process.env, PATH: process.env.PATH + ":/Users/omestre/.foundry/bin" } }
  ).toString().trim();
  const pass = mine.toLowerCase() === ref.toLowerCase();
  ok = ok && pass;
  console.log(`${pass ? "PASS" : "FAIL"} | ${c.symbol} | js=${mine.slice(0, 26)}... cast=${ref.slice(0, 26)}...`);
}
console.log(ok ? "\nENCODER VALIDADO (3/3)" : "\nDIVERGENCIA — corrigir antes de usar");
process.exit(ok ? 0 : 1);
