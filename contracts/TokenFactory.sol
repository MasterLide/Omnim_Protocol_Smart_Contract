// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/ISubToken.sol";
import "./interfaces/IVeToken.sol";
import "./interfaces/IDataNft.sol";

contract TokenFactory is
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
    event ApplicationThresholdUpdated(uint256 newThreshold);

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
        address usdtToken_,
        address nft_,
        uint256 applicationThreshold_,
        address vault_
    ) public initializer {
        __Pausable_init();

        tokenImplementation.push(tokenImplementation_);
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

        _createNewSubToken(id, name, symbol, modelId, decimals, totalSupply, initialOwner);
        return id;
    }

    function _createNewSubToken(
        uint256 id,
        string memory name,
        string memory symbol,
        uint8 modelId,
        uint8 decimals,
        uint256 totalSupply,
        address initialOwner
    ) internal returns (address instance) {
        Application storage application = _applications[id];
        uint256 initialAmount = application.withdrawableAmount;
        application.withdrawableAmount = 0;
        application.status = ApplicationStatus.Executed;

        instance = Clones.clone(tokenImplementation[modelId]);

        ISubToken(instance).initialize(
                    name,
                    symbol,
                    decimals,
                    totalSupply,
                    initialOwner
        );

        allSubTokens.push(instance);

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
        (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) = getAmounts(modelId,initialAmount);

        IERC20(assetToken).approve(assetVeToken, stakeAmount);
        IVeToken(assetVeToken).stake(
                stakeAmount,
                instance,
                instance
        );

        if(burnAmount > 0) ISubToken(assetToken).burn(burnAmount);
        if(poolAmount > 0) IERC20(assetToken).transfer(_vault, poolAmount);

        emit NewPersona(subTokenId, instance, address(0), address(0), address(0));  

        return instance;
    }

    function totalSubTokens() public view returns (uint256) {
        return allSubTokens.length;
    }

    function getApplicationThreshold() public view returns (uint256) {
        if (_uniswapRouter == address(0)) return applicationThreshold;
        address[] memory path = new address[](2);
        path[0] = usdtToken;
        path[1] = assetToken;
        uint[] memory amounts = IRouter(_uniswapRouter).getAmountsOut(applicationThreshold, path);
        return amounts[amounts.length - 1];
    }

    function getPoolSupply(uint8 modelId, uint256 totalSupply) public view returns (uint256) {
        if (modelId == 0 || poolPoint == 0) return 0;
        return totalSupply * poolPoint / DENOMINATOR;
    }

    function getAmounts(uint8 modelId, uint256 amount) public view returns (uint256 stakeAmount, uint256  poolAmount, uint256 burnAmount) {
        burnAmount = amount * burnPoint / DENOMINATOR;
        poolAmount = (modelId == 0 || poolPoint == 0) ? 0 : amount * poolPoint / DENOMINATOR;
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

    function addImplementations(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenImplementation.push(token);
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
