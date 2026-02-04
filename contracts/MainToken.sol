pragma solidity ^0.8.20;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MainToken is ERC20Capped, Ownable {
    constructor(uint256 _initialSupply, address initialOwner) ERC20("Main Protocol", "MAIN") ERC20Capped(1000000000*10**18) Ownable(initialOwner){
        ERC20._mint(msg.sender, _initialSupply);
    }

    function mint(address _to, uint256 _amount) onlyOwner external {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}