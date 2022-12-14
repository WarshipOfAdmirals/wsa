// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./WSA.sol";

contract WSAStaking{
    
    WSA wsaCtc;
    mapping(address => stakeInfo) _addressToStakeInfo;
    uint256 _rewardRatePerMinute = 1 * 10**16;  // 1%


    struct stakeInfo{
        uint256 amount;
        uint256 startTime;
    }

    constructor(WSA _wsaCtc) {
        wsaCtc = _wsaCtc;
    }

    function stake(uint256 amount) public {
        stakeInfo memory oldInfo = _addressToStakeInfo[msg.sender];

        if (oldInfo.amount > 0){
            uint256 rewardAmount = calcReward(oldInfo);
            wsaCtc.transfer(msg.sender, rewardAmount);
        }

        // TODO emit event
        wsaCtc.transferFrom(msg.sender, address(this), amount);
        stakeInfo memory newInfo = stakeInfo(amount + oldInfo.amount, block.timestamp);
        _addressToStakeInfo[msg.sender] = newInfo;
    }

    function harvest() public {
        stakeInfo storage info = _addressToStakeInfo[msg.sender];
        uint256 rewardAmount = calcReward(info);
        info.startTime = block.timestamp;
        wsaCtc.transfer(msg.sender, rewardAmount);
    }

    function calcReward(stakeInfo memory info) internal view returns(uint256){
        return info.amount * _rewardRatePerMinute * (block.timestamp - info.startTime) / 60;
    }

    function unstake() public {
        stakeInfo memory info = _addressToStakeInfo[msg.sender];
        require(info.amount > 0, "You haven't staked any coins yet.");
        stakeInfo memory newInfo = stakeInfo(0, 0);
        _addressToStakeInfo[msg.sender] = newInfo;
        wsaCtc.transfer(msg.sender, info.amount + calcReward(info));

    }

    function stakedAmount() public view returns(uint256){
        return _addressToStakeInfo[msg.sender].amount;
    }
}
