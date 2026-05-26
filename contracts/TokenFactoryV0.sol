// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/ISubToken.sol";
import "./interfaces/IVeToken.sol";
import "./interfaces/IMinerPool.sol";
import "./interfaces/ISubMinerPool.sol";
import "./interfaces/ISubMinerPoolV0.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract TokenFactoryV0 is
    Initializable,
    AccessControl,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    enum ApplicationStatus {
        Active,
        Executed,
        Withdrawn
    }

    struct Application {       
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        address initialOwner;
        ApplicationStatus status;
        uint256 stakeAmount;
        uint256 lpAmount;
        address proposer;
        uint256 subTokenId;
    }

    struct SubTokenInfo {
        address token;       
        address pool; 
        address veToken; 
        address minerPool;
        address founder;
        uint256 stakeAmount;
        uint256 poolSupply;
        uint256 withdrawAbleAt;
    }

    uint256 private _nextId;
    uint256 private applicationThreshold = 200 * 10 **18;
    uint256 private lpThreshold = 200 * 10 **18;
    address private _uniswapRouter;     
    uint256 private _nextSubTokenId;

    uint256 public stakeLockTime = 3600 * 24 * 100;
    uint256 public maturityDuration = 0; 
    uint256 public constant DENOMINATOR = 10000;
    uint256 public burnPoint = 0; 

    address public assetToken; 
    address public assetVeToken;  
    address[] public tokenImplementation;
    address[] public allSubTokens;
    address public veTokenImplementation;
    address[] public allVeTokens;
    address public minerPoolImplementation;
    address[] public allMinerPools;

    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE"); // Able to withdraw and execute applications
    bool internal locked;

    mapping(uint256 => Application) private _applications;
    mapping(uint256 => SubTokenInfo) private subTokenInfos;
    mapping(uint256 => bool) private _blacklists;

    event NewPersona(uint256 virtualId, address token, address dao, address veToken, address lp);
    event NewApplication(uint256 id);
    event ApplicationExecuted(uint256 id);   
    event ApplicationWithdraw(uint256 id);
    event ApplicationThresholdUpdated(uint256 newThreshold);
    event SubTokenBlacklisted(uint256 indexed subTokenId, bool value);
    event SubTokenStakeWithdraw(uint256 subTokenId);

    modifier noReentrant() {
        require(!locked, "cannot reenter");
        locked = true;
        _;
        locked = false;
    }

    ///////////////////////////////////////////////////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        //_disableInitializers();
    }

    function initialize(
        address tokenImplementation_,
        address assetToken_,
        address assetVeToken_,
        address veTokenImplementation_,
        address minerPoolImplementation_
    ) public initializer {
        __Pausable_init();

        tokenImplementation.push(tokenImplementation_);
        veTokenImplementation = veTokenImplementation_;
        minerPoolImplementation = minerPoolImplementation_;
        assetToken = assetToken_;
        assetVeToken = assetVeToken_;
        _nextId = 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _nextSubTokenId = 1;
    }

    function getApplication(
        uint256 proposalId
    ) public view returns (Application memory) {
        return _applications[proposalId];
    }

    function getSubTokenInfo(
        uint256 subTokenId_
    ) public view returns (SubTokenInfo memory) {
        return subTokenInfos[subTokenId_];
    }

    function proposeSubToken(
        string memory name,
        string memory symbol,       
        uint8 decimals,
        uint256 totalSupply,
        address initialOwner,
        uint256 pledgeAmount,
        uint256 liquidityAmount
    ) public whenNotPaused returns (uint256) {
        address sender = _msgSender();
        require(
            liquidityAmount >= lpThreshold,
            "Insufficient asset token"
        );
        require(
            pledgeAmount >= applicationThreshold,
            "Insufficient asset token"
        );
        require(
            IERC20(assetToken).balanceOf(sender) >= (pledgeAmount + liquidityAmount),
            "Insufficient asset token"
        );
        require(
            IERC20(assetToken).allowance(sender, address(this)) >=
                (pledgeAmount + liquidityAmount),
            "Insufficient asset token allowance"
        );

        IERC20(assetToken).safeTransferFrom(
            sender,
            address(this),
            (pledgeAmount + liquidityAmount)
        );

        uint256 id = _nextId++;
        Application memory application = Application(
            name,
            symbol,
            decimals,
            totalSupply,
            initialOwner,
            ApplicationStatus.Active,
            pledgeAmount,
            liquidityAmount,
            sender,
            0            
        );
        _applications[id] = application;
        emit NewApplication(id);
        return id;
    }

    function withdraw(uint256 id) public noReentrant {
        Application storage application = _applications[id];

        require(
            msg.sender == application.proposer ||
                hasRole(WITHDRAW_ROLE, msg.sender),
            "Not proposer"
        );

        require(
            application.status == ApplicationStatus.Active,
            "Application is not active"
        );

        uint256 withdrawableAmount = (application.lpAmount + application.stakeAmount);

        application.lpAmount = 0;
        application.stakeAmount = 0;
        application.status = ApplicationStatus.Withdrawn;

        IERC20(assetToken).safeTransfer(
            application.proposer,
            withdrawableAmount
        );
        emit ApplicationWithdraw(id);
    }

    function withdrawStake(uint256 id) public noReentrant {
        Application storage application = _applications[id];

        require(
            msg.sender == application.proposer ||
                hasRole(WITHDRAW_ROLE, msg.sender),
            "Not proposer"
        );

        require(
            application.status == ApplicationStatus.Executed,
            "Application is not Executed"
        );

        SubTokenInfo storage subTokenInfo = subTokenInfos[application.subTokenId];

        require(
            block.timestamp >= subTokenInfo.withdrawAbleAt,
            "Not mature yet"
        );

        uint256 withdrawableAmount = subTokenInfo.stakeAmount;
        subTokenInfo.stakeAmount = 0;

        ISubMinerPoolV0(subTokenInfo.minerPool).withdraw(withdrawableAmount);
        IERC20(assetToken).safeTransfer(
            application.proposer,
            withdrawableAmount
        );
        emit SubTokenStakeWithdraw(application.subTokenId);
    }

// executeApplication()
// This will bootstrap an Agent with following components:
// C1: SubToken
// C2: LP Pool + Initial liquidity
// C3: veToken
// C4: subMinerPool
// C5: Stake liquidity token to get veToken
// C6: Set and save info
    function executeApplication(uint256 id, bool canStake, uint256 _point) public noReentrant {
        Application storage application = _applications[id];

        require( _point <= DENOMINATOR,"point too big");

        require(
            msg.sender == application.proposer ||
                hasRole(WITHDRAW_ROLE, msg.sender),
            "Not proposer"
        );

        _executeApplication(id, canStake,_point,0);
    }

    function executeApplication(uint256 id, bool canStake, uint256 _point, uint8 modelId) public noReentrant {
        Application storage application = _applications[id];

        require( _point <= DENOMINATOR,"point too big");

        require(
            msg.sender == application.proposer ||
                hasRole(WITHDRAW_ROLE, msg.sender),
            "Not proposer"
        );

        _executeApplication(id, canStake,_point,modelId);
    }

    function _executeApplication(
        uint256 id,
        bool canStake,
        uint256 _point,
        uint8 modelId
    ) internal {
        require(
            _applications[id].status == ApplicationStatus.Active,
            "Application is not active"
        );

        Application storage application = _applications[id];
        uint256 poolSupply = application.totalSupply * _point / DENOMINATOR;
        uint256 burnAmount = application.stakeAmount * burnPoint / DENOMINATOR;        
        uint256 stakeAmount = application.stakeAmount - burnAmount;
        uint256 poolAmount = application.lpAmount;

        application.status = ApplicationStatus.Executed;

        // C1 
        address token = _createNewSubToken(
            application.name, 
            application.symbol, 
            modelId, 
            application.decimals, 
            application.totalSupply
            );
        
        //C2
        address lp = _createPair(token);
        _addLiquidity(token,poolSupply,poolAmount);

        // C3
        address veImpl = veTokenImplementation;
        address veToken = _createNewVeToken(
            string.concat("Staked ", application.name),
            string.concat("s", application.symbol),
            veImpl,
            lp,
            canStake
        );

        //C4
        address minerPool = _createSubMinerPool(
            veToken,
            stakeAmount
        );

        // C5
        uint256 subTokenId = _nextSubTokenId++;
        application.subTokenId = subTokenId;
        _stake(lp,veToken,application.initialOwner);

        // C6
        SubTokenInfo memory subTokenInfo = SubTokenInfo(
            token,      
            lp, 
            veToken,
            minerPool,
            application.proposer,
            stakeAmount,
            poolSupply,
            block.timestamp + stakeLockTime
        );
        subTokenInfos[subTokenId] = subTokenInfo;

        // Other
        uint256 subAmount = IERC20(token).balanceOf(address(this));
        if( subAmount > 0) IERC20(token).transfer(application.initialOwner, subAmount);
        if(burnAmount > 0) ISubToken(assetToken).burn(burnAmount);

        emit NewPersona(subTokenId, token, minerPool, veToken, lp);
        emit ApplicationExecuted(id);  
    }

    function _createNewSubToken(
        string memory name,
        string memory symbol,
        uint8 modelId,
        uint8 decimals,
        uint256 totalSupply
    ) internal returns (address instance) {
        instance = Clones.clone(tokenImplementation[modelId]);        
        ISubToken(instance).initialize(
            name,
            symbol,
            decimals,
            totalSupply,
            address(this)
        );
        allSubTokens.push(instance);
    }

    function _createPair(address subToken) internal returns (address uniswapV2Pair_) {
        uniswapV2Pair_ = IUniswapV2Factory(IUniswapV2Router02(_uniswapRouter).factory()).getPair(
            subToken,
            assetToken
        );

        if (uniswapV2Pair_ == address(0)) {
            uniswapV2Pair_ = IUniswapV2Factory(IUniswapV2Router02(_uniswapRouter).factory())
                .createPair(subToken, assetToken);
        }
        return (uniswapV2Pair_);
    }

    function _addLiquidity(address subToken, uint256 subAmount, uint256 assetAmount) internal {
        require(subAmount > 0 && assetAmount > 0, "No Token For LiquidityPair");

        IERC20(subToken).approve(address(_uniswapRouter), subAmount);
        IERC20(assetToken).approve(address(_uniswapRouter), assetAmount);
        IUniswapV2Router02(_uniswapRouter)
            .addLiquidity(
                subToken,
                assetToken,
                subAmount,
                assetAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
    }

    function _createNewVeToken(
        string memory name,
        string memory symbol,
        address veImpl,
        address lp,
        bool canstake
    ) internal returns (address instance) {
        instance = Clones.clone(veImpl);
        IVeToken(instance).initialize(
            name,
            symbol,
            address(this),
            lp,
            block.timestamp + maturityDuration,
            canstake
        );

        allVeTokens.push(instance);
        return instance;
    }

    function _createSubMinerPool(
        address subVeToken,
        uint256 stakeAmount
    ) internal returns (address instance) {
        {
            instance = Clones.clone(minerPoolImplementation);
            address minerPool = IVeToken(assetVeToken).mineaddr();
            address mineToken = IMinerPool(minerPool).mineToken();
            ISubMinerPool(instance).initialize(
                mineToken,
                subVeToken,
                minerPool
            );
            allMinerPools.push(instance);
            IVeToken(subVeToken).setMiner(instance);
        }  
        IERC20(assetToken).approve(assetVeToken, stakeAmount);
        IVeToken(assetVeToken).stake(
            stakeAmount,
            instance,
            instance
        );     

        return instance;
    }

    function _stake(
        address lp,
        address subVeToken,
        address account
    ) internal {
        IERC20(lp).approve(subVeToken, type(uint256).max);
        IVeToken(subVeToken).stake(
            IERC20(lp).balanceOf(address(this)),
            account,
            account
        );
    }

    function totalSubTokens() public view returns (uint256) {
        return allSubTokens.length;
    }

    function getApplicationThreshold() public view returns (uint256) {
        return applicationThreshold;
    }

    function getLpThreshold() public view returns (uint256) {
        return lpThreshold;
    }

    function setBurnPoint(uint256 newBurnPoint) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newBurnPoint < DENOMINATOR, "Insufficient set number");
        burnPoint = newBurnPoint;
    }

    function setImpls(address token, address vetoken, address minerpool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenImplementation[0] = (token);
        veTokenImplementation = vetoken;
        minerPoolImplementation = minerpool;
    }

    function addPrivateTokenImpl(address tokenImpl) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenImplementation.push(tokenImpl);
    }
   
    function setUniswapRouter(
        address router
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _uniswapRouter = router;
    }

    function setAssetToken(
        address newToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        assetToken = newToken;
    }

    function setAssetVeToken(
        address newVeToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        assetVeToken = newVeToken;
    }

    function setMaturityDuration(
        uint256 newDuration
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maturityDuration = newDuration;
    }

    function setApplicationThreshold(
        uint256 newApplicationThreshold
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        applicationThreshold = newApplicationThreshold;
    }

    function setLpThreshold(
        uint256 newLpThreshold
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lpThreshold = newLpThreshold;
    }

    function setStakeLockTime(
        uint256 newLockTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        stakeLockTime = newLockTime;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function isBlacklisted(uint256 subTokenId) public view returns (bool) {
        return _blacklists[subTokenId];
    }

    function setBlacklist(
        uint256 subTokenId,
        bool value
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklists[subTokenId] = value;
        emit SubTokenBlacklisted(subTokenId, value);
    }

    function executeOperations(
        address  targets,
        uint256  values,
        bytes memory calldatas
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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

    function _msgSender()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (address sender)
    {
        sender = ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ContextUpgradeable._msgData();
    }

    function _contextSuffixLength() internal view override(Context,ContextUpgradeable) returns (uint256) {
        return ContextUpgradeable._contextSuffixLength();
    }
}
