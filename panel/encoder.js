// Encoder ABI do constructor(uint256,string,string,uint8)
// Usado pelo painel e testável via Node (ver test-encoder.mjs)

function pad32(hexNo0x) {
  return hexNo0x.padStart(64, "0");
}

function encodeString(str) {
  const bytes = new TextEncoder().encode(str);
  const lenHex = bytes.length.toString(16).padStart(64, "0");
  let data = "";
  for (const b of bytes) data += b.toString(16).padStart(2, "0");
  const padded = data.padEnd(Math.ceil(data.length / 64) * 64, "0");
  return lenHex + padded;
}

// constructor(uint256 _initialSupply, string _name, string _symbol, uint8 _decimals)
function encodeConstructorArgs({ supply, name, symbol, decimals }) {
  const encName = encodeString(name);
  const encSymbol = encodeString(symbol);
  const offsetName = 32 * 4; // header = 4 palavras de 32 bytes
  const offsetSymbol = offsetName + encName.length / 2; // bytes do name (len+data)
  return (
    pad32(supply.toString(16)) +
    pad32(offsetName.toString(16)) +
    pad32(offsetSymbol.toString(16)) +
    pad32(decimals.toString(16)) +
    encName +
    encSymbol
  );
}

if (typeof module !== "undefined") {
  module.exports = { encodeConstructorArgs, encodeString };
}
