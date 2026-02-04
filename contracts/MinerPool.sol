// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MinerPool is Initializable, AccessControl {
    using Math for uint256;
    using SafeERC20 for IERC20;

    struct Mines {
        uint256 mineNumber;
        uint256 pledgeAmount;
    }

    struct MineSettings {
        uint256 firstDayMines;
        uint256 decayPerDay;
        uint16 userMineBase;
        uint16 userMineAddPerDay;
    }

    struct Claim {
        uint256 totalClaimed;
        uint256 rewardCount; 
    }

    struct StakeInfo {
        uint256 stakerAmount;
        uint256 stakerDayCount; 
    }

    event RefContractsUpdated(address mineToken, address stakeContract);

    event TokenSaved(address indexed by, address indexed receiver, address indexed token, uint256 amount);

    event StakerRewardClaimed(address indexed staker, uint256 numRewards, uint256 amount);

    error NotGovError();

    error NotOwnerError();

    uint256 public constant DENOMINATOR = 10000;
    bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
    bytes32 public constant TOKEN_SAVER_ROLE = keccak256("TOKEN_SAVER_ROLE");
    uint8 public constant LOOP_LIMIT = 30;
    uint64 public constant ONE_DAY = 3600 * 24;

    address public mineToken;
    address public stakeContract;

    Mines[] private _mines;
    mapping(address user => StakeInfo[]) private _userStakes;

    MineSettings private _mineSettings;
    bool public mineIsOpened;
    uint256 mineOpenTime;

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
        uint256 firstDayMines,
        uint256 decayPerDay,
        uint16 userMineBase,
        uint16 userMineAddPerDay
    ) external initializer {
        mineToken = mineToken_;
        stakeContract = stakeContract_;

        _mineSettings.firstDayMines = firstDayMines;
        _mineSettings.decayPerDay = decayPerDay;
        _mineSettings.userMineBase = userMineBase;
        _mineSettings.userMineAddPerDay = userMineAddPerDay;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        mineIsOpened = false;
    }

    function getMineSettings() public view returns (MineSettings memory) {
        return _mineSettings;
    }

    function getMine(uint256 pos) public view returns (Mines memory) {
        return _mines[pos];
    }

    function minesCount() public view returns (uint256) {
        return _mines.length;
    }

    function getStake(address _user, uint256 pos) public view returns (StakeInfo memory) {
        return _userStakes[_user][pos];
    }

    function stakesCount(address _user) public view returns (uint256) {
        return _userStakes[_user].length;
    }

    // ----------------
    // Mine
    // ----------------
    function openMine() public onlyGov {
        if(mineOpenTime != 0) return;
        mineIsOpened = true;
        mineOpenTime = block.timestamp;
        Mines memory _mine = Mines(
            _mineSettings.firstDayMines, IERC20(stakeContract).totalSupply()
        );
        _mines.push(_mine);
    }

    function doMine() public {
        if(!mineIsOpened) return;
        uint256 dayCount = (block.timestamp - mineOpenTime)/ONE_DAY + 1;
        uint256 numMines = Math.min(LOOP_LIMIT, dayCount - minesCount());
        if(numMines == 0) return;
        uint256 baseAmount_ = _mines[minesCount() - 1].mineNumber;
        uint256 decay_ = _mineSettings.decayPerDay;
        uint256 _pledgeAmount = IERC20(stakeContract).totalSupply();

        for (uint i = 0; i < numMines; i++) {
            if(decay_ >= baseAmount_){
                mineIsOpened = false;
                break;
            }

            baseAmount_ -= decay_;
            Mines memory _mine = Mines(baseAmount_, _pledgeAmount);
            _mines.push(_mine);
        } 
    }

    // ----------------
    // Stake/romve
    // ----------------
    function newStake(address _user, uint256 _stakeAmount) public {
        if(_msgSender() != stakeContract) revert NotOwnerError();
        doMine();

        uint256 dayCount = mineOpenTime == 0 ? 0 : (block.timestamp - mineOpenTime)/ONE_DAY + 1;
        uint lastIndex = stakesCount(_user);
        uint256 lastDayCount = lastIndex == 0 ? 0 : _userStakes[_user][lastIndex-1].stakerDayCount;           
        if(lastDayCount == dayCount && lastIndex > 0){
            _userStakes[_user][lastIndex-1].stakerAmount += _stakeAmount;
        }
        else{
            StakeInfo memory _stakeInfo = StakeInfo(_stakeAmount,dayCount);
            _userStakes[_user].push(_stakeInfo);
        }       
    }

    function removeStake(address _user, uint256 _stakeAmount) public {
        if(_msgSender() != stakeContract) revert NotOwnerError();
        claimMyMines(_user);

        uint lastIndex = _userStakes[_user].length;
        if(lastIndex == 0) return;

        for (uint i = lastIndex; i > 0; i--) {
            uint256 _Amount = _userStakes[_user][i-1].stakerAmount;
            if(_Amount > _stakeAmount){
                _userStakes[_user][i-1].stakerAmount = _Amount - _stakeAmount;
                break;
            }
            _stakeAmount -= _Amount;
            _userStakes[_user].pop();
        }      
    }

    // ----------------
    // Claim mines
    // ----------------
    mapping(address account => Claim claim) _mineClaims;

    function getUserClaimed(address _user) public view returns (Claim memory) {
        return _mineClaims[_user];
    }

    function _getClaimMines(
        uint256 amount, 
        uint256 dayCount, 
        uint256 mineNumber,
        uint256 pledgeAmount,
        uint256 mineCount
        ) internal view returns (uint256 claimMines) {
            if(dayCount > mineCount){
                claimMines = 0;
            }
            else{
                uint256 baseMines = Math.mulDiv(amount, mineNumber, pledgeAmount);
                uint256 userNum = _mineSettings.userMineBase + _mineSettings.userMineAddPerDay * ( mineCount - dayCount);
                if(userNum > DENOMINATOR) userNum = DENOMINATOR;
                claimMines = Math.mulDiv(baseMines, userNum, DENOMINATOR);
            }
    }

    function getClaimableMines(address account,uint256 stakeIndex) public view returns (uint256 totalClaimable, uint256 numRewards) {
        if(stakeIndex >= stakesCount(account)) return(0,0);
        Claim memory claim = _mineClaims[account];
        StakeInfo memory _stakeinfo = _userStakes[account][stakeIndex];
        numRewards = Math.min(
            LOOP_LIMIT + claim.rewardCount,
            minesCount()
        );

        for (uint i = claim.rewardCount; i < numRewards; i++) {
            uint256 stakerReward = _getClaimMines(
                _stakeinfo.stakerAmount,
                _stakeinfo.stakerDayCount, 
                _mines[i].mineNumber, 
                _mines[i].pledgeAmount, 
                i);
            totalClaimable += stakerReward;
        }
    }

    function getTotalClaimableMines(address account) public view returns (uint256 totalClaimable, uint256 numRewards) {
        StakeInfo[] memory _stakeinfos = _userStakes[account];

        for (uint i = 0; i < _stakeinfos.length; i++) {
            (uint256 claimable, uint256 numReward) = getClaimableMines(
                account,
                i
            );
            totalClaimable += claimable;
            numRewards = numReward;
        }
    }

    function claimMyMines(address account) public noReentrant {
        doMine();

        uint256 totalClaimable;
        uint256 numRewards;
        (totalClaimable, numRewards) = getTotalClaimableMines(account);

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
    function setMineSettings(
        uint256 firstDayMines,
        uint256 decayPerDay,
        uint16 userMineBase,
        uint16 userMineAddPerDay
    ) public onlyGov {
        if(mineOpenTime != 0) return;
        _mineSettings.firstDayMines = firstDayMines;
        _mineSettings.decayPerDay = decayPerDay;
        _mineSettings.userMineBase = userMineBase;
        _mineSettings.userMineAddPerDay = userMineAddPerDay;
    }

    function updateRefContracts(
        address mineToken_,
        address stakeContract_
    ) external onlyGov {
        mineToken = mineToken_;
        stakeContract = stakeContract_;

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
