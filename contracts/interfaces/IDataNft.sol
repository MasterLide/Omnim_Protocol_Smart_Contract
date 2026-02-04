// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDataNft {

    function mint(
        uint256 id,
        address to,
        string memory newTokenURI,
        address payable theDAO,
        address founder,
        address pool,
        address token
    ) external returns (uint256);

    function nextSubTokenId() external view returns (uint256);
}