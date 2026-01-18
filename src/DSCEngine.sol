//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";


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
 * Our DSC System should always be "overcollateralized", meaning the $ value of all the collateral should always be more than
 the $ backed value of all the DSC minted.
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
    error DSCEngine__TransferFailed();
    error DSCEngine__TransactionBreaksHealthFactor();
    error DSCEngine__TokensLengthAndPriceFeedsLengthMismatch();


    ///////////////////////////
    /////     Events     /////
    /////////////////////////
    event CollateralDeposited(address indexed sender, uint256 indexed amount);
    event RedeemedCollateral(address indexed withdrawer, uint256 indexed amount);


    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    mapping (address collateral => address priceFeed) s_priceFeeds;
    mapping (address user => mapping (address token => uint256 amount)) s_collateralBalances;
    mapping (address user => uint256 amount) s_dscBalances;

    address[] s_collateralTokens;


    ////////////////////////////////
    /////     constructor     /////
    //////////////////////////////
    constructor(address[] memory _collateralTokens, address[] memory _priceFeeds) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert DSCEngine__TokensLengthAndPriceFeedsLengthMismatch();
        }

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_collateralTokens.push(_collateralTokens[i]);
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
        }
    }

    ///////////////////////////////////////
    /////     External Functions     /////
    /////////////////////////////////////
    function depositCollateral(address _collateralToken, uint256 _amount) external {
        if (_amount == 0) revert DSCEngine__MustBeMoreThanZero();
        s_collateralBalances[msg.sender][_collateralToken] += _amount;

        emit CollateralDeposited(msg.sender, _amount);
    }

    function redeemCollateral(address _collateralToken, uint256 _amount) external nonReentrant {
        uint256 balance = s_collateralBalances[msg.sender][_collateralToken];
        if (balance < _amount) revert DSCEngine__InsufficientBalance();

        s_collateralBalances[msg.sender][_collateralToken] -= _amount;
        emit RedeemedCollateral(msg.sender, _amount);

        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert DSCEngine__TransferFailed();

        // _revertIfHealthFactorIsBroken(msg.sender);
    }

    // function depositCollateralForDsc(address _collateralToken, uint256 _amount) external {
    //     _revertIfHealthFactorIsBroken(msg.sender);
    // }
    
    // function mintDsc() external {}

    // function burnDsc() external {}

    // function liquidate(address user) external {}

    // /////////////////////////////////////
    // /////     Public Functions     /////
    // ///////////////////////////////////
    // function getAccountCollateralValue(address _user) public view returns (uint256 accountCollateralValue) {
    //     for (uint256 i = 0; i < s_collateralTokens.length; i ++) {
    //         address token = s_collateralTokens[i];
    //         uint256 amount = s_collateralBalances[_user][token];
    //         uint256 usdValue = getUsdValue(token, amount);
    //         uint256 totalCollateralValueInUsd = usdValue++;
    //     }
    // }

    // //////////////////////////////////////////
    // /////     Pure & View Functions     /////
    // ////////////////////////////////////////
    // function getHealthFactor(address _user) external view returns (uint256) {}
    // function getCollateralValueInUsd() external view {}

    // function getUsdValue(address token, uint256 amount) public view returns (uint256 collateralValueInUsd) {
    //     return collateralValueInUsd;
    // }



    // ///////////////////////////////////////
    // /////     Internal Functions     /////
    // /////////////////////////////////////
    // function _revertIfHealthFactorIsBroken(address _user) internal {
    //     uint256 healthFactor = getHealthFactor(_user);

    //     if (healthFactor < 1) revert DSCEngine__TransactionBreaksHealthFactor();
    // }

    // function _healthFactor(address _user) internal view returns (
    //         uint256 totalDscMinted,
    //         uint256 collateralValueInUsd
    //     ) {
    //     return (totalDscMinted, collateralValueInUsd) = _getAccountInformation(_user);
    // }

    // function _getAccountInformation(address _user) internal view returns (
    //         uint256 totalDscMinted,
    //         uint256 collateralValueInUsd
    //     ) {
    //         totalDscMinted = s_dscBalances[_user];
    //     }
}