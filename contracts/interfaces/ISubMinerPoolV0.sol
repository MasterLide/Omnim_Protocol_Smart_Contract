// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISubMinerPoolV0 {
    function initialize(
        address mineToken_,
        address stakeContract_,
        address minerPool_
    ) external ;

    function mineToken() external view returns (address);

    function newStake(address _user, uint256 _stakeAmount) external;

    function removeStake(address _user, uint256 _stakeAmount)external;

    function grantRole(bytes32 role, address account) external;

    function claimMyMines(address account) external;

    function withdraw(uint256 amount) external;

    function stakeContract() external view returns(address);

    function GOV_ROLE() external view returns(bytes32);

    function TOKEN_SAVER_ROLE() external view returns(bytes32);
}
