// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Marco Hurtado
 *
 * The system is designed to be as minimas as possible, and have the tokens maintain a 1 token = 1 USD peg. The system is overcollateralized to account for price volatility of the collateral assets.
 * This stable coin has the properteis:
 * - Exogenos Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no gobernance, no fees, and was only backed by WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point should the value of all collateral <= the value of all DSC.
 *
 * @notice this cotnract is the core of the system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice this contract is very loosely based on the MakerDAO DSS (DAI) system. It is not a copy, but it is similar in many ways.
 */
contract DSCEngine is ReentrancyGuard {
    // errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TokenAddressAndPriceFeedAddressLengthMismatch();
    error DSCEngine__TransferFailed();
    error DSCEngine__NoMinted();
    error DSCEngine__BreaksHealthFactor(uint256 healtFactor);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNNotImproved();

    // State variables
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds; // token address => price feed address
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // token address => is allowed
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    // Modifiers
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //Functions
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressLengthMismatch();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
            s_collateralTokens.push(_tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    /**
     * @param _token token address to deposit as collateral
     * @param _amount amount of collateral to deposit
     * @param _amountToMint amount of DSC to mint
     */
    function depositCollateralAndMintDsc(address _token, uint256 _amount, uint256 _amountToMint) external {
        depositCollateral(_token, _amount);
        mintDsc(_amountToMint);
    }

    /**
     * @notice this function allows users to deposit collateral into the system. The collateral is used to back the DSC that is minted.
     * @param _token The address of the token to deposit as collateral
     * @param _amount The amount of collateral to deposit
     */
    function depositCollateral(address _token, uint256 _amount)
        public
        moreThanZero(_amount)
        isAllowedToken(_token)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_token] += _amount;
        emit CollateralDeposited(msg.sender, _token, _amount);
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice this function allows users to redeem their collateral by burning their DSC. The amount of collateral that can be redeemed is based on the amount of DSC that is burned and the current price of the collateral.
     * @param _token The address of the token to redeem as collateral
     * @param _amount The amount of collateral to redeem
     * @param _amountToBurn The amount of DSC to burn
     */
    function redeemCollateralForDsc(address _token, uint256 _amount, uint256 _amountToBurn) external {
        burnDsc(_amountToBurn);
        redeemCollateral(_token, _amount);
        // reddemCollateral and burnDsc are both nonReentrant, so we don't need to add it here
    }

    /**
     * @notice this function allows users to redeem their collateral without burning their DSC. The amount of collateral that can be redeemed is based on the amount of DSC that is minted and the current price of the collateral.
     * @param _token The address of the token to redeem as collateral
     * @param _amount The amount of collateral to redeem
     */
    function redeemCollateral(address _token, uint256 _amount)
        public
        moreThanZero(_amount)
        isAllowedToken(_token)
        nonReentrant
    {
        _redeemCollateral(_token, _amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follow CEI
     * @notice they must have more collateral value than the minimum threshold
     * @param _amountToMint  The amout of decentralized stablecoin to mint
     */
    function mintDsc(uint256 _amountToMint) public moreThanZero(_amountToMint) nonReentrant {
        s_DSCMinted[msg.sender] += _amountToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amountToMint);
        if (!minted) {
            revert DSCEngine__NoMinted();
        }
    }

    function burnDsc(uint256 _amount) public moreThanZero(_amount) {
        _burnDsc(msg.sender, _amount, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice this function allows users to liquidate undercollateralized positions. The liquidator will receive a discount on the collateral that is being liquidated.
     * @param collateral The address of the token to liquidate as collateral
     * @param user The address of the user to liquidate
     * @param debtToCover The amount of DSC to burn in order to cover the debt
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDsc(msg.sender, debtToCover, user);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view returns (uint256) {
        // return health factor of a position
    }

    // Private and Internal View Functions

    /**
     * @notice this function reverts if the health factor of the user is below the minimum health factor. The health factor is calculated as follows:
     * health factor = (collateral value * liquidation threshold) / debt value
     * If the health factor is below 1, then the user can be liquidated.
     */
    function _burnDsc(address _from, uint256 _amount, address _onBehalfOf) private {
        s_DSCMinted[_onBehalfOf] -= _amount;
        bool success = i_dsc.transferFrom(_from, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amount);
    }

    function _redeemCollateral(address _token, uint256 _amount, address _from, address _to) private {
        s_collateralDeposited[_from][_token] -= _amount;
        emit CollateralRedeemed(_from, _to, _token, _amount);
        bool success = IERC20(_token).transfer(_to, _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get lequidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(healthFactor);
        }
    }

    // Public and External View Functions

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd, uint256 healthFactor)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
        healthFactor = _healthFactor(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }
}
