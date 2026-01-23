// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract RedeemCollateral is Test {
    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    DeployDsc deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address wEth;
    address wBtc;
    address wEthUsdPriceFeed;
    address wBtcUsdPriceFeed;

    address user;
    address RANDOM_TOKEN = makeAddr("randomToken");
    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant AMOUNT_DEPOSIT = 5 ether;
    uint256 constant AMOUNT_REDEEM = 5 ether;
    uint256 constant STARTING_MINTED_TOKENS = 10 ether;

    //////////////////////////
    /////     SetUp     /////
    ////////////////////////
    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wEthUsdPriceFeed, wBtcUsdPriceFeed, wEth, wBtc,) = helperConfig.activeNetworkConfig();

        user = makeAddr("user");
        vm.deal(user, 10 ether);
        ERC20Mock(wEth).mint(user, STARTING_MINTED_TOKENS);
        ERC20Mock(wBtc).mint(user, STARTING_MINTED_TOKENS);
    }

    /////////////////////////////
    /////     Modifier     /////
    ///////////////////////////
    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();
        _;
    }

    modifier depositedBtcCollateral() {
        vm.startPrank(user);
        ERC20Mock(wBtc).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wBtc, AMOUNT_DEPOSIT);
        vm.stopPrank();
        _;
    }

    ////////////////////////////////////////////
    /////     Redeem Collateral Tests     /////
    //////////////////////////////////////////
    function testRedeemCollateral() public depositedCollateral {
        uint256 startingUserBalance = dscEngine.getUserCollateralAmount(user, wEth);

        vm.startPrank(user);
        dscEngine.redeemCollateral(wEth, AMOUNT_REDEEM);
        vm.stopPrank();

        uint256 endingUserBalance = dscEngine.getUserCollateralAmount(user, wEth);

        assertEq(endingUserBalance, startingUserBalance - AMOUNT_REDEEM);
    }

    function testMultipleRedeemCollateral() public depositedCollateral depositedBtcCollateral {
        uint256 startingUserEthBalance = dscEngine.getUserCollateralAmount(user, wEth);
        uint256 startingUserBtcBalance = dscEngine.getUserCollateralAmount(user, wBtc);
        (, uint256 startingUserUsdBalance) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        ERC20Mock(wBtc).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(wEth, AMOUNT_REDEEM);
        dscEngine.redeemCollateral(wBtc, AMOUNT_REDEEM);
        vm.stopPrank();

        //Collateral Token Balance
        uint256 endingUserEthBalance = dscEngine.getUserCollateralAmount(user, wEth);
        uint256 endingUserBtcBalance = dscEngine.getUserCollateralAmount(user, wBtc);

        //USD Balance
        uint256 redeemedEthUsdValue = dscEngine.getUsdValue(wEth, AMOUNT_DEPOSIT);
        uint256 redeemedBtcUsdValue = dscEngine.getUsdValue(wBtc, AMOUNT_DEPOSIT);
        uint256 expectedTotalRedeemedUsd = redeemedEthUsdValue + redeemedBtcUsdValue;
        (, uint256 endingUserUsdBalance) = dscEngine.getAccountInformation(user);

        assertEq(endingUserEthBalance, startingUserEthBalance - AMOUNT_REDEEM);
        assertEq(endingUserBtcBalance, startingUserBtcBalance - AMOUNT_REDEEM);
        assertEq(endingUserUsdBalance, startingUserUsdBalance - expectedTotalRedeemedUsd);
    }

    function testRedeemUpdatesCollateralBalance() public depositedCollateral {
        uint256 startingUserBalance = ERC20Mock(wEth).balanceOf(user);

        vm.startPrank(user);
        dscEngine.redeemCollateral(wEth, AMOUNT_REDEEM);
        vm.stopPrank();

        uint256 endingUserBalance = ERC20Mock(wEth).balanceOf(user);

        assertEq(endingUserBalance, startingUserBalance + AMOUNT_REDEEM);
    }

    function testRedeemCollateralEmits() public depositedCollateral {
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit DSCEngine.RedeemedCollateral(user, user, wEth, AMOUNT_REDEEM);
        dscEngine.redeemCollateral(wEth, AMOUNT_REDEEM);
        vm.stopPrank();
    }

    function testRevertRedeemIfAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.redeemCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertDepositIfTokenIsNotAllowed() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.redeemCollateral(RANDOM_TOKEN, AMOUNT_REDEEM);
        vm.stopPrank();
    }
}
