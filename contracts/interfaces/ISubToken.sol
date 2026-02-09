// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISubToken is IERC20 {

    function mint(address _to, uint256 _amount) external;

    function burn(uint256 value) external;

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        address initialOwner
    ) external;

    function executeOperations(
        address  targets,
        uint256  values,
        bytes memory calldatas
    ) external;

    function transferOwnership(address newOwner) external;
}