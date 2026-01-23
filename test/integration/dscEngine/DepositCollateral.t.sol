// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract DepositCollateral is Test {
    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    DeployDsc deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address wEth;
    address wEthUsdPriceFeed;

    address user;
    address RANDOM_TOKEN = makeAddr("randomToken");
    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant AMOUNT_DEPOSIT = 5 ether;
    uint256 constant STARTING_ETH_BALANCE = 10 ether;

    //////////////////////////
    /////     SetUp     /////
    ////////////////////////
    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wEthUsdPriceFeed,, wEth,,) = helperConfig.activeNetworkConfig();

        user = makeAddr("user");
        vm.deal(user, 10 ether);
        ERC20Mock(wEth).mint(user, STARTING_ETH_BALANCE);
    }

    /////////////////////////////////////////////
    /////     Deposit Collateral Tests     /////
    ///////////////////////////////////////////
    function testDepositCollateral() public {
        (, uint256 startingUserBalance) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();

        uint256 expectedUsdIncrease = dscEngine.getUsdValue(wEth, AMOUNT_DEPOSIT);

        (, uint256 endingUserBalance) = dscEngine.getAccountInformation(user);

        assertEq(endingUserBalance, startingUserBalance + expectedUsdIncrease);
    }

    function testMultipleDepositCollateral() public {
        (, uint256 startingUserBalance) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();

        uint256 firstDepositValueInUsd = dscEngine.getUsdValue(wEth, AMOUNT_DEPOSIT);
        uint256 secondDepositValueInUsd = dscEngine.getUsdValue(wEth, AMOUNT_DEPOSIT);
        uint256 expectedUsdIncrease = firstDepositValueInUsd + secondDepositValueInUsd;

        (, uint256 endingUserBalance) = dscEngine.getAccountInformation(user);

        assertEq(endingUserBalance, startingUserBalance + expectedUsdIncrease);
    }

    function testDepositUpdatesCollateralBalance() public {
        uint256 startingUserBalance = dscEngine.getUserCollateralAmount(user, wEth);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();

        uint256 endingUserBalance = dscEngine.getUserCollateralAmount(user, wEth);

        assertEq(endingUserBalance, startingUserBalance + AMOUNT_DEPOSIT);
    }

    function testDepositCollateralEmits() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, true, true);
        emit DSCEngine.CollateralDeposited(user, wEth, AMOUNT_DEPOSIT);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();
    }

    function testRevertDepositIfAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertDepositIfTokenIsNotAllowed() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(RANDOM_TOKEN, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
}
