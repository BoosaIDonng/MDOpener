#!/usr/bin/env node
// MD Opener 专业版 key 生成器（发货池工具）
//
// key 的生成与校验逻辑在 docs/pro-keys.js（与官网页面共用同一份，
// 改那边=这边同步）。本脚本只负责命令行输入输出。
//
// 用法：
//   node tools/keygen.mjs          打印 100 个 key（粘贴到收款平台发货池）
//   node tools/keygen.mjs <key>    校验某个 key 是否有效

import '../docs/pro-keys.js';

const { generate, isValid } = globalThis.MDOpenerKeys;

const arg = process.argv[2];
if (arg) {
  const ok = isValid(arg);
  console.log(ok ? '✓ 有效 key' : '✗ 无效 key');
  process.exit(ok ? 0 : 1);
} else {
  generate().forEach(k => console.log(k));
}
