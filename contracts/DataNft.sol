// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract DataNft is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable
{
    struct SubTokenInfo {
        address dao; // Agent DAO can update the agent metadata
        address token;
        address founder;
        address pool; // Liquidity pool for the agent
        address veToken; // Voting escrow token
        //address miner;
    }

    uint256 private _nextSubTokenId;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => uint256) private _stakingTokenToSubTokenId;
    mapping(address => uint256) private _subTokenId;   
    mapping(uint256 => SubTokenInfo) public subTokenInfos;
    mapping(uint256 => bool) private _blacklists;

    event SubTokenBlacklisted(uint256 indexed subTokenId, bool value);


    modifier onlySubTokenDAO(uint256 subTokenId) {
        require(
            _msgSender() == subTokenInfos[subTokenId].dao,
            "Caller is not SubToken DAO"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        //_disableInitializers(); 
    }

    function initialize(address defaultAdmin) public initializer {
        __ERC721_init("Data", "DATA");
        __ERC721URIStorage_init();

        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(ADMIN_ROLE, defaultAdmin);
        _nextSubTokenId = 1;
    }

    function nextSubTokenId() public view returns (uint256) {
        return _nextSubTokenId;
    }

    function mint(
        uint256 subTokenId,
        address to,
        string memory newTokenURI,
        address payable theDAO,
        address founder,
        address pool,
        address token
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(subTokenId == _nextSubTokenId, "Invalid subTokenId");
        _nextSubTokenId++;
        _mint(to, subTokenId);
        _setTokenURI(subTokenId, newTokenURI);
        SubTokenInfo storage info = subTokenInfos[subTokenId];
        info.dao = theDAO;
        info.founder = founder;
        IERC5805 daoToken = theDAO == address(0) ? IERC5805(address(0)) : GovernorVotes(theDAO).token();
        info.token = token;
        info.pool = pool;
        info.veToken = address(daoToken);

        _subTokenId[token] = subTokenId;
        _stakingTokenToSubTokenId[address(daoToken)] = subTokenId;

        return subTokenId;
    }

    function subTokenInfo(
        uint256 subTokenId
    ) public view returns (SubTokenInfo memory) {
        return subTokenInfos[subTokenId];
    }

    function tokenToSubTokenId(
        address _token
    ) public view returns (uint256) {
        return _subTokenId[_token];
    }

    function stakingTokenToSubTokenId(
        address stakingToken
    ) external view returns (uint256) {
        return _stakingTokenToSubTokenId[stakingToken];
    }

    function setTokenURI(
        uint256 subTokenId,
        string memory newTokenURI
    ) public onlySubTokenDAO(subTokenId) {
        return _setTokenURI(subTokenId, newTokenURI);
    }

    function setDAO(uint256 subTokenId, address newDAO) public onlySubTokenDAO(subTokenId) {
        SubTokenInfo storage info = subTokenInfos[subTokenId];
        info.dao = newDAO;
    }

    function totalStaked(uint256 subTokenId) public view returns (uint256) {
        return IERC20(subTokenInfos[subTokenId].veToken).totalSupply();
    }

    function getVotes(
        uint256 subTokenId,
        address validator
    ) public view returns (uint256) {
        return IERC5805(subTokenInfos[subTokenId].veToken).getVotes(validator);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function totalSupply() public view returns (uint256) {
        return _nextSubTokenId - 1;
    }

    function isBlacklisted(uint256 subTokenId) public view returns (bool) {
        return _blacklists[subTokenId];
    }

    function setBlacklist(
        uint256 subTokenId,
        bool value
    ) public onlyRole(ADMIN_ROLE) {
        _blacklists[subTokenId] = value;
        emit SubTokenBlacklisted(subTokenId, value);
    }

    function migrateSubToken(
        uint256 subTokenId,
        address dao,
        address token,
        address pool,
        address veToken
    ) public onlyRole(ADMIN_ROLE) {
        SubTokenInfo storage info = subTokenInfos[subTokenId];
        info.dao = dao;
        info.token = token;
        info.pool = pool;
        info.veToken = veToken;
        _subTokenId[token] = subTokenId;
        _stakingTokenToSubTokenId[address(veToken)] = subTokenId;
    }
}
