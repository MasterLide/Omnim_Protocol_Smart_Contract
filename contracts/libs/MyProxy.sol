// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MyProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address initialOwner, bytes memory _data) TransparentUpgradeableProxy(_logic,initialOwner,_data) {}

    function getProxyAdmin() public view returns (address) { return _proxyAdmin(); }
}