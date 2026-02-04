// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IMinerPool.sol";
import "./interfaces/IVeToken.sol";

contract SubMinerPool is Initializable, AccessControl {
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

    event RefContractsUpdated(address mineToken, address stakeContract);

    event TokenSaved(address indexed by, address indexed receiver, address indexed token, uint256 amount);

    event StakerRewardClaimed(address indexed staker, uint256 numRewards, uint256 amount);

    error NotGovError();

    error NotOwnerError();

    uint256 public constant DENOMINATOR = 10000;
    bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
    bytes32 public constant TOKEN_SAVER_ROLE = keccak256("TOKEN_SAVER_ROLE");
    uint8 public constant LOOP_LIMIT = 100;

    address public mineToken;
    address public stakeContract;
    address public minerPool;

    Mines[] private _mines;
    mapping(address user => uint256) private _userStakes;
    mapping(address account => Claim claim) _mineClaims;

    modifier onlyTokenSaver() {
        require(hasRole(TOKEN_SAVER_ROLE, _msgSender()), "TokenSaver.onlyTokenSaver: permission denied");
        _;
    }

    modifier onlyGov() {
        if (!hasRole(GOV_ROLE, _msgSender())) {
            revert NotGovError();
        }
        _;
    }

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

    function AddMinePower(uint256 _power) public onlyGov {
        if(minerPool == address(0)) return;
        address gov_ = _msgSender();
        uint256 beforeAmoumt = IERC20(mineToken).balanceOf(address(this));
        address powerPool = IMinerPool(minerPool).stakeContract();
        address powerToken = IVeToken(powerPool).assetToken();
        IERC20(powerToken).transferFrom(gov_, address(this), _power);
        IERC20(powerToken).approve(powerPool, _power);
        IVeToken(powerPool).stake(_power, address(this), gov_);

        uint256 afterAmoumt = IERC20(mineToken).balanceOf(address(this));

        if(afterAmoumt > beforeAmoumt) _AddMine(afterAmoumt - beforeAmoumt);
    }

    function RemoveMinePower(uint256 _power) public onlyGov {
        if(minerPool == address(0)) return;
        uint256 beforeAmoumt = IERC20(mineToken).balanceOf(address(this));
        address powerPool = IMinerPool(minerPool).stakeContract();
        IVeToken(powerPool).withdraw(_power);
        uint256 afterAmoumt = IERC20(mineToken).balanceOf(address(this));

        if(afterAmoumt > beforeAmoumt) _AddMine(afterAmoumt - beforeAmoumt); 
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

    // ----------------
    // Manage parameters
    // ----------------
    function updateRefContracts(
        address mineToken_,
        address stakeContract_,
        address minerPool_
    ) external onlyGov {
        mineToken = mineToken_;
        stakeContract = stakeContract_;
        minerPool = minerPool_;

        emit RefContractsUpdated(mineToken_, stakeContract_);
    }

    // ----------------
    // TokenSaver
    // ----------------

    function saveToken(address _token, address _receiver, uint256 _amount) external onlyTokenSaver {
        IERC20(_token).safeTransfer(_receiver, _amount);
        emit TokenSaved(_msgSender(), _receiver, _token, _amount);
    }
}
