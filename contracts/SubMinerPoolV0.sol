// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IMinerPool.sol";
import "./interfaces/IVeToken.sol";

contract SubMinerPoolV0 is Initializable, AccessControl {
    using Math for uint256;
    using SafeERC20 for IERC20;

    struct Mines {
        uint256 mineNumber;
        uint256 pledgeAmount;
    }

    struct Claim {
        uint256 totalClaimed;
        uint256 rewardCount; 
    }

    event StakerRewardClaimed(address indexed staker, uint256 numRewards, uint256 amount);

    error NotOwnerError();

    uint8 public constant LOOP_LIMIT = 100;

    address public mineToken;
    address public stakeContract;
    address public minerPool;

    Mines[] private _mines;
    mapping(address user => uint256) private _userStakes;
    mapping(address account => Claim claim) _mineClaims;

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "cannot reenter");
        locked = true;
        _;
        locked = false;
    }

    function initialize(
        address mineToken_,
        address stakeContract_,
        address minerPool_
    ) external initializer {
        mineToken = mineToken_;
        stakeContract = stakeContract_;
        minerPool = minerPool_;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getMine(uint256 pos) public view returns (Mines memory) {
        return _mines[pos];
    }

    function minesCount() public view returns (uint256) {
        return _mines.length;
    }

    function getStake(address _user) public view returns (uint256) {
        return _userStakes[_user];
    }

    // ----------------
    // Mine
    // ----------------

    function doMine() public {
        if(minerPool == address(0)) return;
        uint256 beforeAmoumt = IERC20(mineToken).balanceOf(address(this));
        IMinerPool(minerPool).claimMyMines(address(this));
        uint256 afterAmoumt = IERC20(mineToken).balanceOf(address(this));

        if(afterAmoumt > beforeAmoumt) _AddMine(afterAmoumt - beforeAmoumt);
    }

    function _AddMine(uint256 _Amoumt) private {
        Mines memory _mine = Mines(
            _Amoumt, 
            IERC20(stakeContract).totalSupply()
            );
        _mines.push(_mine);
    }

    // ----------------
    // Stake/romve
    // ----------------
    function newStake(address _user, uint256 _stakeAmount) public {
        if(_msgSender() != stakeContract) revert NotOwnerError();
        claimMyMines(_user);
        _userStakes[_user] += _stakeAmount;      
    }

    function removeStake(address _user, uint256 _stakeAmount) public {
        if(_msgSender() != stakeContract) revert NotOwnerError();
        claimMyMines(_user);
        uint256 _Amount = _userStakes[_user];
        _userStakes[_user] = _stakeAmount > _Amount ? 0 : _Amount - _stakeAmount;     
    }

    // ----------------
    // Claim mines
    // ----------------


    function getUserClaimed(address _user) public view returns (Claim memory) {
        return _mineClaims[_user];
    }

    function getClaimableMines(address account) public view returns (uint256 totalClaimable, uint256 numRewards) {
        Claim memory claim = _mineClaims[account];
        uint256 _Amount = _userStakes[account];
        numRewards = minesCount();

        for (uint i = claim.rewardCount; i < numRewards; i++) {
            uint256 stakerReward = Math.mulDiv(
                _Amount,
                _mines[i].mineNumber, 
                _mines[i].pledgeAmount
                );
            totalClaimable += stakerReward;
        }
    }

    function claimMyMines(address account) public noReentrant {
        doMine();

        uint256 totalClaimable;
        uint256 numRewards;
        (totalClaimable, numRewards) = getClaimableMines(account);

        Claim storage claim = _mineClaims[account];
        claim.totalClaimed += totalClaimable;
        claim.rewardCount = numRewards;

        IERC20(mineToken).safeTransfer(account, totalClaimable);

        emit StakerRewardClaimed(
            account,
            numRewards,
            totalClaimable
        );
    }

    function withdraw(uint256 amount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "permission denied");
        if(minerPool == address(0)) return;
        address powerPool = IMinerPool(minerPool).stakeContract();
        IVeToken(powerPool).withdraw(amount);

        IERC20(mineToken).safeTransfer(_msgSender(), amount); 
    }
}
