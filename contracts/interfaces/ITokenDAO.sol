// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface ITokenDAO {
    function initialize(
        string memory name,
        IVotes token,
        uint256 threshold,
        uint32 votingPeriod_
    ) external;
}