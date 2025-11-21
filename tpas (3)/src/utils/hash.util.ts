import crypto from "crypto";

export function generateLowerHash(length: number = 12) {
  const alphabet = "abcdefghijklmnopqrstuvwxyz123456789";

  const bitsNeeded = length * 5;
  const bytesNeeded = Math.ceil(bitsNeeded / 8);

  const bytes = crypto.randomBytes(bytesNeeded);

  let bits = "";
  for (const byte of bytes) {
    bits += byte.toString(2).padStart(8, "0");
  }

  let out = "";
  for (let i = 0; i < bits.length; i += 5) {
    const chunk = bits.slice(i, i + 5);
    if (chunk.length < 5) break;
    out += alphabet[parseInt(chunk, 2)];
  }

  return out.slice(0, length);
}
