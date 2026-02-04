// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMinerPool {
    function newStake(address _user, uint256 _stakeAmount) external;

    function removeStake(address _user, uint256 _stakeAmount)external;

    function claimMyMines(address account) external;

    function stakeContract() external view returns(address);
}
