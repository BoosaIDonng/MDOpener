// MD Opener 专业版 key 生成与校验（共享文件）
//
// 由固定种子确定性生成 100 个 key，仓库不存任何明文列表。
// 同时被两处使用，改动这里两边同步生效：
//   - 官网页面 docs/index.html（<script src="pro-keys.js">，挂到 window）
//   - 发货池生成脚本 tools/keygen.mjs（Node 导入，挂到 globalThis）
//
// 种子公开在仓库里，任何人都能跑出同样的 key——定位是君子协议，不是防盗版。
// 想作废整批换一批：改 SEED 即可，旧 key 全部失效。
(function (root) {
  const SEED = 'mdopener-pro-v1';
  const COUNT = 100;
  const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // 去掉易混淆的 0/O/1/I/L

  // cyrb53 字符串哈希 → 32 位整数种子
  function hashSeed(str) {
    let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
    for (let i = 0; i < str.length; i++) {
      const ch = str.charCodeAt(i);
      h1 = Math.imul(h1 ^ ch, 2654435761);
      h2 = Math.imul(h2 ^ ch, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return h2 >>> 0;
  }

  // mulberry32 确定性 PRNG：纯整数运算，浏览器与 Node 结果逐位一致（不能用 Math.random）
  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function generate(seed = SEED, count = COUNT) {
    const rnd = mulberry32(hashSeed(seed));
    const keys = new Set();
    while (keys.size < count) {
      let body = '';
      for (let i = 0; i < 10; i++) body += ALPHABET[Math.floor(rnd() * ALPHABET.length)];
      keys.add(`MDOP-${body.slice(0, 5)}-${body.slice(5)}`);
    }
    return [...keys];
  }

  // 归一化：大写并去掉所有非字母数字字符（对用户多粘了空格、漏了横杠宽容）
  function normalize(input) {
    return String(input || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  }

  function isValid(input) {
    const n = normalize(input);
    if (!n) return false;
    return generate().some(k => normalize(k) === n);
  }

  root.MDOpenerKeys = { SEED, COUNT, generate, normalize, isValid };
})(typeof window !== 'undefined' ? window : globalThis);
