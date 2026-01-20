//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/**
 * @title DSCEngine
 * @author Southrays
 * 
 * This system is designed to be as minimal as possible, and have the tokens maintain a 1:1 peg with the USD dollar.
 * This Stablecoin has the properties:
 *  - Exogenous Collateral
 *  - Dollar Pegged
 *  - Algorithmically Stable
 * 
 * Its is backed by wEth and wBtc.
 * 
 * Our DSC System should always be "200% overcollateralized", meaning that the $ value of all the collateral should always be
 2 times more than the $ backed value of all the DSC minted.
 * 
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC,
 as well as depositing and withdrawing collateral.
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////////////
    /////     Errors     /////
    /////////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__InsufficientBalance();
    error DSCEngine__DepositFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__BurnFailed();
    error DSCEngine__RedeemFailed();
    error DSCEngine__TransactionBreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorIsNotBroken();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__TokensLengthAndPriceFeedsLengthMismatch();
    error DSCEngine__NotAllowedToken();



    ///////////////////////////
    /////     Events     /////
    /////////////////////////
    event CollateralDeposited(address indexed sender, address indexed collateralToken, uint256 indexed amount);
    event RedeemedCollateral(address indexed redeemedFrom, address redeemedTo, address indexed collateralToken, uint256 indexed amount);
    event DscMinted(address indexed to, uint256 indexed amount);
    event DscBurned(address indexed from, uint256 indexed amount);



    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% Overcollateralized.
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; //This means 10% would be given to the liquidator.
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    mapping (address collateralToken => address priceFeed) s_priceFeeds;
    mapping (address user => mapping (address token => uint256 amount)) s_collateralBalances;
    mapping (address user => uint256 amount) s_dscBalances;

    address[] s_collateralTokens;
    DecentralizedStablecoin private immutable i_dsc;



    //////////////////////////////
    /////     Modifiers     /////
    ////////////////////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) revert DSCEngine__MustBeMoreThanZero();
        _;
    }

    modifier isTokenAllowed(address _collateralToken) {
        if (s_priceFeeds[_collateralToken] == address(0)) revert DSCEngine__NotAllowedToken();
        _;
    }



    ////////////////////////////////
    /////     constructor     /////
    //////////////////////////////
    constructor(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds,
        address _dscAddress
        ) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert DSCEngine__TokensLengthAndPriceFeedsLengthMismatch();
        }

        //Mapping the pricefeed address to it's collateral token address.
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_collateralTokens.push(_collateralTokens[i]);
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
        }
        i_dsc = DecentralizedStablecoin(_dscAddress);
    }



    ///////////////////////////////////////
    /////     External Functions     /////
    /////////////////////////////////////
    /**
     * This functions allows users to Deposit collateral tokens and Mint DSC in one transaction.
     * @param _collateralToken The address of the collateral token being deposited.
     * @param _amountCollateral The amount of collateral tokens to be deposited.
     * @param _amountDscToMint The amount of DSC tokens to be minted.
     */
    function depositCollateralAndMintDsc(address _collateralToken, uint256 _amountCollateral, uint256 _amountDscToMint) 
        external  
        nonReentrant 
    {
        depositCollateral(_collateralToken, _amountCollateral);
        mintDsc(_amountDscToMint);
    }


    /**
     * This functions allows users to Redeem their deposited collateral tokens and Burn DSC in one transaction.
     * @param _collateralToken The collateral token to redeem.
     * @param _amountCollateral The amount of collateral tokens to redeem.
     * @param _amountDscToBurn The amount of DSC to burn.
     */
    function RedeemCollateralForDsc(address _collateralToken, uint256 _amountCollateral, uint256 _amountDscToBurn) 
        external
        nonReentrant
    {
        burnDsc(_amountDscToBurn);
        redeemCollateral(_collateralToken, _amountCollateral);
    }


    /**
     * This function Liquidates user's who have broken the Health Factor and are below
     * the MIN_HEALTH_FACTOR.
     * It ensure that after the liquidation process, the Health Factor of the user is improved.
     * Follows CEI.
     * @param _user The user who is is being liquidated. This user must have a Health Factor
     that is below the MIN_HEALTH_FACTOR in order to be liquidated.
     * @param _collateral The collateral token to liquidate from the user.
     * @param _debtToCover The amount of DSC to burn, to improve the user's Health Factor.
     * @notice You can partially liquidate a user, so long as you improve their Health Factor.
     * @notice This liquidation works properly if the protocol is roughly 200% overcollateralized.
     * @notice If the protocol is 100% or less collateralized, then the protocol wouldn't be able
     to incentivize liquidators. e.g if the price of the collateral plummeted before anyone could
     be liquidated.
     */
    function liquidate(address _user, address _collateral, uint256 _debtToCover) 
        external 
        moreThanZero(_debtToCover) 
        isTokenAllowed(_collateral)
        nonReentrant 
    {   
        uint256 startingHealthFactor = _healthFactor(_user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorIsNotBroken();

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsdAmount(_collateral, _debtToCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(_user, msg.sender, _collateral, totalCollateralToRedeem);

        _burnDsc(_user, msg.sender, _debtToCover);

        uint256 endingHealthFactor = _healthFactor(_user);

        if (endingHealthFactor <= startingHealthFactor) revert DSCEngine__HealthFactorNotImproved();

        _revertIfHealthFactorIsBroken(msg.sender);
    }



    /////////////////////////////////////
    /////     Public Functions     /////
    ///////////////////////////////////
    /**
     * This functions allows users to deposit allowed collateral tokens.
     * It ensures the user is depositing more than zero.
     * Deposits are updated to the (s_collateralBalances) and emitted.
     * @notice Follows CEI.
     * @param _collateralToken The address of the collateral token being deposited.
     * @param _amountCollateral The amount of collateral tokens being deposited.
     */
    function depositCollateral(address _collateralToken, uint256 _amountCollateral) 
        public 
        moreThanZero(_amountCollateral) 
        isTokenAllowed(_collateralToken) 
        nonReentrant
    {
        s_collateralBalances[msg.sender][_collateralToken] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _collateralToken, _amountCollateral);

        bool deposited = IERC20(_collateralToken).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!deposited) revert DSCEngine__DepositFailed();
    }


    /**
     * This functions allows users to Mint DSC.
     * It ensures that the user is minting more than Zero.
     * It ensures that the Mint does not break the user's Health Factor.
     * Mints are updated to the (s_dscBalances) and emitted.
     * @notice Follows CEI.
     * @param _amountDscToMint The amount of DSC tokens to be minted.
     */
    function mintDsc(uint256 _amountDscToMint) 
        public 
        moreThanZero(_amountDscToMint) 
        nonReentrant 
    {
        s_dscBalances[msg.sender] += _amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        emit DscMinted(msg.sender, _amountDscToMint);

        bool minted = i_dsc.mint(msg.sender, _amountDscToMint);
        if (!minted) revert DSCEngine__MintFailed();
    }


    /**
     * This functions allows users to Redeem their deposited collateral tokens.
     * It ensures the user is not Redeeming Zero tokens or more than what they have deposited.
     * It ensures the user is only Redeeming allowed tokens.
     * It ensures that the user does not break Health Factor by redeeming these tokens.
     * If the Health Factor would be broken, it reverts.
     * The (s_collateralBalances) of the user is updated and the withdrawal is emitted if
     the transaction is successful and does not break the Health Factor.
     * @notice Follows CEI.
     * @param _collateralToken The address of the collateral token being deposited.
     * @param _amountCollateral The amount of collateral tokens being deposited.
     */
    function redeemCollateral(address _collateralToken, uint256 _amountCollateral) 
        public 
        moreThanZero(_amountCollateral) 
        isTokenAllowed(_collateralToken) 
        nonReentrant 
    {   
        _redeemCollateral(msg.sender, msg.sender, _collateralToken, _amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    /**
     * This functions allows users to Burn their DSC.
     * It ensures that the user is burning more than Zero.
     * Burns are updated to the (s_dscBalances) and emitted.
     * @notice Follows CEI.
     * @param _amountDscToBurn The amount of DSC tokens to be minted.
     */
    function burnDsc(uint256 _amountDscToBurn) 
        public 
        moreThanZero(_amountDscToBurn) 
        nonReentrant 
    {
        _burnDsc(msg.sender, msg.sender, _amountDscToBurn);
    }



    //////////////////////////////////////////////////////
    /////     Private & Internal View Functions     /////
    ////////////////////////////////////////////////////
    /**
     * This functions allows collateral to be Redeemed.
     * The collateral tokens can be redeemed by the user or a liquidator who is redeeming
     the collateral of a user with a broken Health Factor (Health Factor < MIN_HEALTH_FACTOR).
     * The (s_collateralBalances) of the liquidated user and the liquidator are updated and 
     the withdrawal is emitted if the transaction is successful.
     * @notice Follows CEI.
     * @param _from The user who has broken the Health Factor and is being liquidated.
     * @param _to The liquidator who the collateral is being transferred to.
     * @param _collateralToken The address of the collateral token being deposited.
     * @param _amountCollateral The amount of collateral tokens being deposited.
     */
    function _redeemCollateral(address _from, address _to, address _collateralToken, uint256 _amountCollateral) 
        private  
        nonReentrant 
    {   
        if (s_collateralBalances[_from][_collateralToken] == 0) revert DSCEngine__InsufficientBalance();
        s_collateralBalances[_from][_collateralToken] -= _amountCollateral;
        emit RedeemedCollateral(_from, _to, _collateralToken, _amountCollateral);

        bool success = IERC20(_collateralToken).transfer(_to, _amountCollateral);
        if (!success) revert DSCEngine__RedeemFailed();
    }


    /**
     * This functions Burns DSC.
     * Burns are updated to the (s_dscBalances) and emitted.
     * @notice Follows CEI.
     * @param _onBehalfOf The user whose dsc balance would be reduced.
     * @param _dscFrom The user who transfers the dsc to be burnt.
     * @param _amountDscToBurn The amount of DSC tokens to be minted.
     */
    function _burnDsc(address _onBehalfOf, address _dscFrom, uint256 _amountDscToBurn) 
        private
        nonReentrant 
    {
        s_dscBalances[_onBehalfOf] -= _amountDscToBurn;
        emit DscBurned(_onBehalfOf, _amountDscToBurn);

        bool burned = i_dsc.transferFrom(_dscFrom, address(this), _amountDscToBurn);
        if (!burned) revert DSCEngine__BurnFailed();
        i_dsc.burn(_amountDscToBurn);
    }


    /**
     * This function gets the total DSC minted by the user and the $ usd
     value of the total collateral deposited by the user.
     * @param _user The user whose account information is being checked
     * @return totalDscMinted The total DSC minted by the user
     * @return collateralValueInUsd The usd value total collateral tokens
     deposited by the user.
     */
    function _getAccountInformation(address _user) private view returns (
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) {
        totalDscMinted = s_dscBalances[_user];
        collateralValueInUsd = getAccountCollateralValue(_user);
    }


    /**
     * This function gets the Health Factor of a user
     * @param _user This is the user whose Health Factor is being checked
     * @return _userHealthFactor This is the Health Factor of the user
     */
    function _healthFactor(address _user) private view returns (uint256 _userHealthFactor) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(_user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        _userHealthFactor = (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;

        //Example (if LIQUIDATION_THRESHOLD = 50)
        // User Deposits -> $500
        // User Mints -> 200 DSC
        // DSC pegged at 1:1 to $ usd. (200 DSC = $200)
        // $500 * 50 = $25,000.
        // $25,000 / 100 = $250  //This means a user who has $500 worth of collateral cannot have more than 250 DSC.
        // _userHealthFactor = $250 * 1e18 / 200 DSC
        // A good Health Factor must be >= 1 (1e18), else the Health Factor is broken.
    }
    

    /**
     * This function reverts if the user's Health Factor is broken.
     * The Health Factor is considered to be broken if it is < 1.
     * @param _user This is the user whose Health Factor is being checked.
     * @notice Function reverts if Health Factor is broken.
     */
    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) revert DSCEngine__TransactionBreaksHealthFactor(userHealthFactor);
    }



    /////////////////////////////////////////////////////
    /////     Public & External View Functions     /////
    ///////////////////////////////////////////////////
    /**
     * This function gets the sum $ usd values of all the collateral tokens the user
     has deposited.
     * @param _user This is the user whose total deposited collateral is being evaluated.
     */
    function getAccountCollateralValue(address _user) public view returns (uint256 accountCollateralValue) {
        for (uint256 i = 0; i < s_collateralTokens.length; i ++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralBalances[_user][token];
            uint256 tokenUsdValue = getUsdValue(token, amount);
            accountCollateralValue = tokenUsdValue++;
        }
    }


    /**
     * This function gets the $ usd price of a specific amount of collateral tokens.
     * It ensures the collateral token being checked is allowed and the token amount
     being checked is more than Zero.
     * @param _collateralToken The address of the collateral token.
     * @param _collateralTokenAmount The amount of collateral token.
     * @notice AggregatorV3Interface from chainlink is used to get the price.
     */
    function getUsdValue(address _collateralToken, uint256 _collateralTokenAmount) 
        public view 
        isTokenAllowed(_collateralToken) 
        moreThanZero(_collateralTokenAmount) 
        returns (uint256 collateralValueInUsd)
    {   
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_collateralToken]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        collateralValueInUsd = ((uint256(price) * ADDITIONAL_FEED_PRECISION) + _collateralTokenAmount) / PRECISION;
    }


    function getTokenAmountFromUsdAmount(address _collateralToken, uint256 _usdAmountInWei) 
        public view 
        moreThanZero(_usdAmountInWei) 
        returns(uint256) 
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_collateralToken]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (_usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

}