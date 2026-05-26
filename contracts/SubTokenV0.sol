// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract SubTokenV0 is ERC20Upgradeable{
    uint8 private _decimals = 18;

    constructor() {}

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address initialOwner
    ) external initializer {
        __ERC20_init(name_, symbol_);
        _decimals = decimals_;
        _mint(initialOwner, totalSupply_);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

