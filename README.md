# Solidity 安全审计实战

## Damn Vulnerable DeFi 8 关全解

🔥 **中文第一套！** 从零到一掌握 DeFi 安全审计核心技能。

---

## 产品包含

### 📖 完整指南（PDF/Markdown）
- 8 关逐行漏洞分析
- 攻击思路 + 攻击合约 + 修复方案
- 真实 DeFi 攻击案例对照
- 赏金平台入门指南（Immunefi / Cantina / Code4rena）
- 进阶学习路线图

### 📦 攻击合约源码（已验证编译）
```
contracts/
├── TrusterAttack.sol        # 任意调用攻击
├── NaiveReceiverAttack.sol   # 借款人未校验
├── SideEntranceAttack.sol    # 存款抵还款
├── PuppetAttack.sol          # 预言机操纵
├── SelfieAttack.sol          # 快照治理攻击
├── RewarderAttack.sol        # 闪电贷刷奖励
├── UnstoppableAttack.sol     # 状态不一致 DoS
└── CompromisedAttack.sol     # 私钥泄露
```

### 🛠 编译脚本
- 一键 `bash compile.sh` 编译所有合约
- 产出 ABI + Bytecode

---

## 覆盖的漏洞类型

| 漏洞类型 | 关卡 | 真实攻击案例 |
|---------|------|-------------|
| 任意调用 | Truster | bZx 攻击 |
| 权限缺失 | Naive Receiver | Eminence |
| 存款漏洞 | Side Entrance | 多起闪电贷 |
| 预言机操纵 | Puppet | Mango Markets ($114M) |
| 治理攻击 | Selfie | Beanstalk ($182M) |
| 奖励操纵 | The Rewarder | Harvest Finance ($24M) |
| DoS | Unstoppable | 多种 |
| 私钥泄露 | Compromised | Wintermute |

---

## 定价

**¥99 / $15**

一次购买，永久更新。

---

## 要求

- Node.js >= 12
- 基础 Solidity 知识
- solcjs（npm install -g solc）

---

## 购买

❤️ [爱发电购买 ¥99](https://afdian.com/a/_6b83b) 支持微信/支付宝

购买后永久更新。

---

## 作者

GitHub: https://github.com/zhangjiayang6835-cyber
