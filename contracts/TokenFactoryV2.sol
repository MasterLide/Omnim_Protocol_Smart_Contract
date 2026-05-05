// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/ISubToken.sol";
import "./interfaces/IVeToken.sol";
import "./interfaces/ITokenDAO.sol";
import "./interfaces/IDataNft.sol";
import "./interfaces/IMinerPool.sol";
import "./interfaces/ISubMinerPool.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract TokenFactoryV2 is
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
        uint8 modelId;
        string name;
        string symbol;
        string tokenURI;
        ApplicationStatus status;
        uint256 withdrawableAmount;
        address proposer;
        uint256 subTokenId;
        uint8 decimals;
        uint256 totalSupply;
        address initialOwner;
    }

    uint256 private _nextId;
    uint256 private applicationThreshold;
    address private _vault; // Vault to hold all Virtual NFTs  
    address private _uniswapRouter;     

    uint256 public constant DENOMINATOR = 10000;
    uint256 public poolPoint;
    uint256 public burnPoint; 
    address public assetToken; // Base currency
    address public assetVeToken; // Base currency
    address public usdtToken;    
    address public nft;
    address[] public tokenImplementation;
    address[] public allSubTokens;
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE"); // Able to withdraw and execute applications
    bool internal locked;

    mapping(uint256 => Application) private _applications;

    event NewPersona(uint256 virtualId, address token, address dao, address veToken, address lp);
    event NewApplication(uint256 id);
    event ApplicationExecuted(uint256 id);
    event ApplicationWithdraw(uint256 id);
    event ApplicationThresholdUpdated(uint256 newThreshold);

    modifier noReentrant() {
        require(!locked, "cannot reenter");
        locked = true;
        _;
        locked = false;
    }

    ///////////////////////////////////////////////////////////////
    //V2
    uint32 daoVotingPeriod = 3600;
    uint256 daoThreshold = 10 * 10 **18;
    uint256 public maturityDuration; // Staking duration in seconds for initial LP. eg: 10years
    address[] public veTokenImplementation;
    address[] public allVeTokens;
    address[] public daoImplementation;
    address[] public allDAOs;
    address[] public minerPoolImplementation;
    address[] public allMinerPools;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        //_disableInitializers();
    }

    function initialize(
        address tokenImplementation_,
        address assetToken_,
        address assetVeToken_,
        address usdtToken_,
        address nft_,
        uint256 applicationThreshold_,
        address vault_
    ) public initializer {
        __Pausable_init();

        tokenImplementation.push(tokenImplementation_);
        veTokenImplementation.push(address(0));
        daoImplementation.push(address(0));
        minerPoolImplementation.push(address(0));
        assetToken = assetToken_;
        assetVeToken = assetVeToken_;
        usdtToken = usdtToken_;
        nft = nft_;
        applicationThreshold = applicationThreshold_;
        _nextId = 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _vault = vault_;
    }

    function getApplication(
        uint256 proposalId
    ) public view returns (Application memory) {
        return _applications[proposalId];
    }

    function proposeSubToken(
        string memory name,
        string memory symbol,
        uint8 modelId,
        uint8 decimals,
        uint256 totalSupply,
        uint256 pledgeAmount,
        address initialOwner
    ) public whenNotPaused returns (uint256) {
        address sender = _msgSender();
        require(
            modelId < tokenImplementation.length,
            "Insufficient modelId"
        );
        require(
            pledgeAmount >= getApplicationThreshold(),
            "Insufficient asset token"
        );
        require(
            IERC20(assetToken).balanceOf(sender) >= pledgeAmount,
            "Insufficient asset token"
        );
        require(
            IERC20(assetToken).allowance(sender, address(this)) >=
                pledgeAmount,
            "Insufficient asset token allowance"
        );

        IERC20(assetToken).safeTransferFrom(
            sender,
            address(this),
            pledgeAmount
        );

        uint256 id = _nextId++;
        Application memory application = Application(
            modelId,
            name,
            symbol,
            name,
            ApplicationStatus.Active,
            pledgeAmount,
            sender,
            0,
            decimals, 
            totalSupply, 
            initialOwner
        );
        _applications[id] = application;
        emit NewApplication(id);

        if(modelId == 0)_createBaseSubToken(id);
        return id;
    }

    function _createBaseSubToken(
        uint256 id
    ) internal{
        // This will bootstrap an Agent with following components:
        // C1: create SubToken
        // C2: mint dataNFT
        // C3: Stake asset token to get veToken
        Application storage application = _applications[id];
        uint256 initialAmount = application.withdrawableAmount;
        application.withdrawableAmount = 0;
        application.status = ApplicationStatus.Executed;
        //C1
        address instance = Clones.clone(tokenImplementation[application.modelId]);        
        ISubToken(instance).initialize(
                    application.name,
                    application.symbol,
                    application.decimals,
                    application.totalSupply,
                    application.initialOwner
        );
        allSubTokens.push(instance);

        //C2
        uint256 subTokenId = IDataNft(nft).nextSubTokenId();
            IDataNft(nft).mint(
                subTokenId,
                _vault,
                application.tokenURI,
                payable(address(0)),
                application.proposer,
                address(0),
                instance
            );
        application.subTokenId = subTokenId;

        //C3
        (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) = getAmounts(application.modelId,initialAmount,0);
        if(stakeAmount > 0 ){
            IERC20(assetToken).approve(assetVeToken, stakeAmount);
            IVeToken(assetVeToken).stake(
                stakeAmount,
                instance,
                instance
            );
        }
        if(burnAmount > 0) ISubToken(assetToken).burn(burnAmount);
        if(poolAmount > 0) IERC20(assetToken).transfer(_vault, poolAmount);

        emit NewPersona(subTokenId, instance, address(0), address(0), address(0));
        emit ApplicationExecuted(id);
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

        uint256 withdrawableAmount = application.withdrawableAmount;

        application.withdrawableAmount = 0;
        application.status = ApplicationStatus.Withdrawn;

        IERC20(assetToken).safeTransfer(
            application.proposer,
            withdrawableAmount
        );
        emit ApplicationWithdraw(id);
    }

    function executeApplication(uint256 id, bool canStake, uint256 _point) public noReentrant {
        // This will bootstrap an Agent with following components:
        // C1: SubToken
        // C2: LP Pool + Initial liquidity
        // C3: veToken
        // C4: tokenDAO
        // C5: dataNFT
        // C6: subMinerPool
        // C7: Stake liquidity token to get veToken

        Application storage application = _applications[id];

        require( (_point + burnPoint) <= DENOMINATOR,"point too big");

        require(
            msg.sender == application.proposer ||
                hasRole(WITHDRAW_ROLE, msg.sender),
            "Not proposer"
        );

        _executeApplication(id, canStake,_point);
    }

    function _executeApplication(
        uint256 id,
        bool canStake,
        uint256 _point
    ) internal {
        require(
            _applications[id].status == ApplicationStatus.Active,
            "Application is not active"
        );

        Application storage application = _applications[id];
        uint256 initialAmount = application.withdrawableAmount;
        uint256 poolSupply = getPoolSupply(application.modelId,application.totalSupply,_point);
        (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) = getAmounts(application.modelId,initialAmount,_point);
        if(poolSupply == 0 || poolAmount == 0) return _createBaseSubToken(id);

        application.withdrawableAmount = 0;
        application.status = ApplicationStatus.Executed;

        // C1 
        address token = _createNewSubToken(
            application.name, 
            application.symbol, 
            application.modelId, 
            application.decimals, 
            application.totalSupply
            );
        
        //C2
        address lp = _createPair(token);
        _addLiquidity(token,poolSupply,poolAmount);

        // C3
        address veImpl = veTokenImplementation[application.modelId];
        address veToken = _createNewVeToken(
            string.concat("Staked ", application.name),
            string.concat("s", application.symbol),
            veImpl,
            lp,
            canStake
        );

        // C4
        string memory daoName = string.concat(application.name, " DAO");
        address daoimpl = daoImplementation[application.modelId];
        address payable dao = payable(
            _createNewDAO(
                daoName,
                daoimpl,
                IVotes(veToken)
            )
        );

        //C5
        uint256 subTokenId = IDataNft(nft).nextSubTokenId();
        IDataNft(nft).mint(
            subTokenId,
            _vault,
            application.tokenURI,
            payable(dao),
            application.proposer,
            lp,
            token
        );
        application.subTokenId = subTokenId;

        //C6
        if(stakeAmount > 0 ) _createSubMinerPool(
            application.modelId,
            token,
            veToken,
            dao,
            stakeAmount
        );

        // C7
        _stake(lp,veToken,application.initialOwner);
        ISubToken(token).transferOwnership(dao);
        uint256 subAmount = IERC20(token).balanceOf(address(this));
        if( subAmount > 0) IERC20(token).transfer(application.initialOwner, subAmount);
        if(burnAmount > 0) ISubToken(assetToken).burn(burnAmount);

        emit NewPersona(subTokenId, token, dao, veToken, lp);
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
/*
    function _createNewSubToken2(
        uint256 id,
        string memory name,
        string memory symbol,
        uint8 modelId,
        uint8 decimals,
        uint256 totalSupply,
        address initialOwner
    ) internal returns (address instance) {
        // This will bootstrap an Agent with following components:
        // C1: SubToken
        // C2: LP Pool + Initial liquidity
        // C3: veToken
        // C4: tokenDAO
        // C5: dataNFT
        // C6: subMinerPool
        // C7: Stake liquidity token to get veToken

        Application storage application = _applications[id];
        uint256 initialAmount = application.withdrawableAmount;
        application.withdrawableAmount = 0;
        application.status = ApplicationStatus.Executed;
        //C1
        instance = Clones.clone(tokenImplementation[modelId]);        
        ISubToken(instance).initialize(
                    name,
                    symbol,
                    decimals,
                    totalSupply,
                    address(this)
        );
        allSubTokens.push(instance);

        uint256 poolSupply = getPoolSupply(modelId,totalSupply);
        (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) = getAmounts(modelId,initialAmount);

        //C2
        address lp = poolAmount > 0 ? _createPair(instance) : address(0);
        if(lp != address(0)) _addLiquidity(instance,poolSupply,poolAmount);

        //C3 
        string memory vename = string.concat("Staked ", application.name);
        string memory vesymbol = string.concat("Staked ", application.symbol);
        address veImpl = veTokenImplementation[modelId];
        address subVeToken = modelId == 0 || lp == address(0) ? address(0) : _createNewVeToken(vename,vesymbol,veImpl,lp);

        //C4
        string memory daoname = string.concat(application.name, " DAO");
        address daoimpl = daoImplementation[modelId];
        address subTokenDAO = subVeToken == address(0) ? address(0) : _createNewDAO(daoname,daoimpl,IVotes(subVeToken));

        //C5
        uint256 subTokenId = IDataNft(nft).nextSubTokenId();
            IDataNft(nft).mint(
                subTokenId,
                _vault,
                application.tokenURI,
                payable(subTokenDAO),
                application.proposer,
                lp,
                instance
            );
        application.subTokenId = subTokenId;
        
        //C6
        if(stakeAmount > 0 ) _createSubMinerPool(modelId,instance,subVeToken,subTokenDAO,stakeAmount);

        // C7
        if (lp != address(0) && subVeToken != address(0)) _stake(lp,subVeToken,initialOwner);
        address subOwner = subTokenDAO == address(0) ? initialOwner : subTokenDAO;
        ISubToken(instance).transferOwnership(subOwner);
        uint256 subAmount = IERC20(instance).balanceOf(address(this));
        if( subAmount > 0) IERC20(instance).transfer(initialOwner, subAmount);
        if(burnAmount > 0) ISubToken(assetToken).burn(burnAmount);

        emit NewPersona(subTokenId, instance, subTokenDAO, subVeToken, lp);  

        return instance;
    }
*/
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

    function _createNewDAO(
        string memory daoname,
        address daoimpl,
        IVotes token
    ) internal returns (address instance) {
        instance = Clones.clone(daoimpl);
        ITokenDAO(instance).initialize(
            daoname,
            token,
            daoThreshold,
            daoVotingPeriod
        );

        allDAOs.push(instance);
        return instance;
    }

    function _createSubMinerPool(
        uint8 modelId,
        address subToken,
        address subVeToken,
        address subVeTokenDAO,
        uint256 stakeAmount
    ) internal returns (address instance) {
        address minerOwner = subVeTokenDAO;
        if(modelId == 0 || subVeTokenDAO == address(0)){
            instance = subToken;
            minerOwner = subToken;
        }else{
            instance = Clones.clone(minerPoolImplementation[modelId]);
            address minerPool = IVeToken(assetVeToken).mineaddr();
            address mineToken = IMinerPool(minerPool).mineToken();
            ISubMinerPool(instance).initialize(
                mineToken,
                subVeToken,
                minerPool
            );
            allMinerPools.push(instance);
            IVeToken(subVeToken).setMiner(instance);
            ISubMinerPool(instance).grantRole(ISubMinerPool(instance).GOV_ROLE(), subVeTokenDAO);
            ISubToken(subVeToken).transferOwnership(subVeTokenDAO);
        }  
        IERC20(assetToken).approve(assetVeToken, stakeAmount);
        IVeToken(assetVeToken).stake(
            stakeAmount,
            instance,
            minerOwner
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
        if (_uniswapRouter == address(0)) return applicationThreshold;
        address[] memory path = new address[](2);
        path[1] = usdtToken;
        path[0] = assetToken;
        uint[] memory amounts = IRouter(_uniswapRouter).getAmountsIn(applicationThreshold, path);
        return amounts[0];
    }

    function getPoolSupply(uint8 modelId, uint256 totalSupply, uint256 _point) public view returns (uint256) {
        if (modelId == 0 || poolPoint == 0) return 0;
        if (_point == 0 ) return totalSupply * poolPoint / DENOMINATOR;
        return totalSupply * _point / DENOMINATOR;
    }

    function getAmounts(uint8 modelId, uint256 amount, uint256 _point) public view returns (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) {
        burnAmount = amount * burnPoint / DENOMINATOR;
        poolAmount = (modelId == 0 || poolPoint == 0) ? 0 : (_point == 0) ? amount * poolPoint / DENOMINATOR : amount * _point / DENOMINATOR;
        stakeAmount = amount - burnAmount - poolAmount;
    }

    function setPoint(uint256 newPoolPoint, uint256 newBurnPoint) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require((newPoolPoint + newBurnPoint) < DENOMINATOR, "Insufficient set number");
        poolPoint = newPoolPoint;
        burnPoint = newBurnPoint;
    }

    function setVault(address newVault) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _vault = newVault;
    }

    function addImplementations(address token, address vetoken, address dao,address minerpool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isMigrated()," No Initialized");
        tokenImplementation.push(token);
        veTokenImplementation.push(vetoken);
        daoImplementation.push(dao);
        minerPoolImplementation.push(minerpool);
    }

    function migrateV1() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_getInitializedVersion() == 1 && tokenImplementation.length == 1,"Migrate Error");
        require(veTokenImplementation.length == 0 && 
            daoImplementation.length == 0 &&
            minerPoolImplementation.length == 0,
            "Migrated Error");
        veTokenImplementation.push(address(0));
        daoImplementation.push(address(0));
        minerPoolImplementation.push(address(0));
    }

    function _isMigrated() internal view returns (bool) {
        return _getInitializedVersion() == 1 && minerPoolImplementation.length >= 1;
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

    function setUsdtToken(
        address newToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        usdtToken = newToken;
    }

    function setMaturityDuration(
        uint256 newDuration
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maturityDuration = newDuration;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
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
