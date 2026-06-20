// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libs/AddressCheckpoints.sol";


interface IMiner {
    function newStake(address _user, uint256 _stakeAmount) external;

    function removeStake(address _user, uint256 _stakeAmount)external;
}

contract VeToken is ERC20Upgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace208;
    using AddressCheckpoints for AddressCheckpoints.Trace;

    address public mineaddr;
    address public assetToken; // This is the token that is staked
    uint256 public matureAt; // The timestamp when the founder can withdraw the tokens
    bool public canStake; // To control private/public agent mode    
    mapping(address => AddressCheckpoints.Trace) private _delegateeCheckpoints;

    constructor() {
        //_disableInitializers();
    }

    function initialize(   
        string memory _name,
        string memory _symbol,
        address _owner,
        address _assetToken,
        uint256 _matureAt,
        bool _canStake) external initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Votes_init();
        __Ownable_init(_owner);

        matureAt = _matureAt;
        assetToken = _assetToken;
        canStake = _canStake;
    }

    mapping(address => Checkpoints.Trace208) private _balanceCheckpoints;

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "cannot reenter");
        locked = true;
        _;
        locked = false;
    }

    function _delegate(address account, address delegatee) internal override {
        super._delegate(account, delegatee);
        _delegateeCheckpoints[account].push(clock(), delegatee);
    }

    function _getPastDelegates(
        address account,
        uint256 timepoint
    ) internal view virtual returns (address) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return
            _delegateeCheckpoints[account].upperLookupRecent(
                SafeCast.toUint48(timepoint)
            );
    }

    // Stakers have to stake their tokens and delegate to a validator
    function stake(uint256 amount, address receiver, address delegatee) public {
        require(
            canStake || totalSupply() == 0,
            "Staking is disabled for private"
        ); // Either public or first staker

        address sender = _msgSender();
        require(amount > 0, "Cannot stake 0");
        require(
            IERC20(assetToken).balanceOf(sender) >= amount,
            "Insufficient asset token balance"
        );
        require(
            IERC20(assetToken).allowance(sender, address(this)) >= amount,
            "Insufficient asset token allowance"
        );

        if(mineaddr != address(0)) IMiner(mineaddr).newStake(receiver, amount);

        IERC20(assetToken).safeTransferFrom(sender, address(this), amount);
        _mint(receiver, amount);
        _delegate(receiver, delegatee);
        _balanceCheckpoints[receiver].push(
            clock(),
            SafeCast.toUint208(balanceOf(receiver))
        );
    }

    function setCanStake(bool _canStake) public onlyOwner{
        canStake = _canStake;
    }

    function setMatureAt(uint256 _matureAt) public onlyOwner{
        matureAt = _matureAt;
    }

    function setMiner(address _miner) public onlyOwner{
        mineaddr = _miner;
    }

    function withdraw(uint256 amount) public noReentrant {
        address sender = _msgSender();
        require(balanceOf(sender) >= amount, "Insufficient balance");
        require(block.timestamp >= matureAt, "Not mature yet");

        if(mineaddr != address(0)) IMiner(mineaddr).removeStake(sender, amount);

        _burn(sender, amount);
        _balanceCheckpoints[sender].push(
            clock(),
            SafeCast.toUint208(balanceOf(sender))
        );

        IERC20(assetToken).safeTransfer(sender, amount);
    }

    function getPastBalanceOf(
        address account,
        uint256 timepoint
    ) public view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return
            _balanceCheckpoints[account].upperLookupRecent(
                SafeCast.toUint48(timepoint)
            );
    }

    // This is non-transferable token
    function transfer(
        address /*to*/,
        uint256 /*value*/
    ) public override returns (bool) {
        revert("Transfer not supported");
    }

    function transferFrom(
        address /*from*/,
        address /*to*/,
        uint256 /*value*/
    ) public override returns (bool) {
        revert("Transfer not supported");
    }

    function approve(
        address /*spender*/,
        uint256 /*value*/
    ) public override returns (bool) {
        revert("Approve not supported");
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    function getPastDelegates(
        address account,
        uint256 timepoint
    ) public view returns (address) {
        return _getPastDelegates(account, timepoint);
    }
}
