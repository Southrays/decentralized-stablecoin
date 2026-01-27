// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract DepositCollateralAndMintDsc is Test {
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
    uint256 constant AMOUNT_MINT = 10;
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

    //////////////////////////////////////////////////////////
    /////     Deposit Collateral And Mint Dsc Tests     /////
    ////////////////////////////////////////////////////////
    function testDepositCollateralAndMintDsc() public {
        uint256 startingUserCollateralBalance = dscEngine.getUserCollateralAmount(user, wEth);
        uint256 startingUserDscBalance = dscEngine.getUserDscBalance(user);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(wEth, AMOUNT_DEPOSIT, AMOUNT_MINT);
        vm.stopPrank();

        uint256 endingUserCollateralBalance = dscEngine.getUserCollateralAmount(user, wEth);
        uint256 endingUserDscBalance = dscEngine.getUserDscBalance(user);

        assertEq(endingUserCollateralBalance, startingUserCollateralBalance + AMOUNT_DEPOSIT);
        assertEq(endingUserDscBalance, startingUserDscBalance + AMOUNT_MINT);
    }

    function testDepositCollateralAndMintDscEmits() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, true, true);
        emit DSCEngine.CollateralDeposited(user, wEth, AMOUNT_DEPOSIT);
        emit DSCEngine.DscMinted(user, AMOUNT_MINT);
        dscEngine.depositCollateralAndMintDsc(wEth, AMOUNT_DEPOSIT, AMOUNT_MINT);
        vm.stopPrank();
    }

    function testRevertDepositCollateralAndMintDscIfAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateralAndMintDsc(wEth, 0, 0);
        vm.stopPrank();
    }

    function testRevertDepositCollateralAndMintDscIfHealthFactorBreaks() public {
        uint256 excessMintAmount = dscEngine.getUsdValue(wEth, AMOUNT_DEPOSIT);

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransactionBreaksHealthFactor.selector);
        dscEngine.depositCollateralAndMintDsc(wEth, AMOUNT_DEPOSIT, excessMintAmount);
        vm.stopPrank();
    }
}