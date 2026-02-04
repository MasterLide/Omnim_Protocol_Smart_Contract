// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract SubToken is ERC20Upgradeable, OwnableUpgradeable{
    using SafeERC20 for IERC20;

    uint8 private _decimals = 18;

    constructor() {
        //_disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 poolSupply_,
        address initialOwner
    ) external initializer {
        __Ownable_init(initialOwner);
        __ERC20_init(name_, symbol_);
        _decimals = decimals_;
        if(poolSupply_ > 0) _mint(_msgSender(), poolSupply_);
        _mint(initialOwner, totalSupply_ - poolSupply_);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address _to, uint256 _amount) onlyOwner external {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function executeOperations(
        address  targets,
        uint256  values,
        bytes memory calldatas
    ) external onlyOwner {
        _executeOperations(targets, values, calldatas);
    }

    function _executeOperations(
        address  targets,
        uint256  values,
        bytes memory calldatas
    ) internal virtual {
            (bool success, bytes memory returndata) = targets.call{value: values}(calldatas);
            Address.verifyCallResult(success, returndata);
    }
}

