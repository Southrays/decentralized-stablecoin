// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract MintDscTests is Test {
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

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wEth, AMOUNT_DEPOSIT);
        vm.stopPrank();
    }

    ///////////////////////////////////
    /////     Mint Dsc Tests     /////
    /////////////////////////////////
    function testMintDsc() public {
        (uint256 startingUserDscBalance,) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        dscEngine.mintDsc(AMOUNT_MINT);
        vm.stopPrank();

        (uint256 endingUserDscBalance,) = dscEngine.getAccountInformation(user);

        assertEq(endingUserDscBalance, startingUserDscBalance + AMOUNT_MINT);
    }

    function testMultipleMintDsc() public {
        (uint256 startingUserDscBalance,) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        dscEngine.mintDsc(AMOUNT_MINT);
        dscEngine.mintDsc(AMOUNT_MINT);
        vm.stopPrank();

        (uint256 endingUserDscBalance,) = dscEngine.getAccountInformation(user);

        assertEq(endingUserDscBalance, startingUserDscBalance + AMOUNT_MINT + AMOUNT_MINT);
    }

    function testMintUpdatesDscBalance() public {
        uint256 startingUserDscBalance = dscEngine.getUserDscBalance(user);

        vm.startPrank(user);
        dscEngine.mintDsc(AMOUNT_MINT);
        vm.stopPrank();

        uint256 endingUserDscBalance = dscEngine.getUserDscBalance(user);

        assertEq(endingUserDscBalance, startingUserDscBalance + AMOUNT_MINT);
    }

    function testMintDscEmits() public {
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit DSCEngine.DscMinted(user, AMOUNT_MINT);
        dscEngine.mintDsc(AMOUNT_MINT);
        vm.stopPrank();
    }

    function testRevertIfMintAmountIsZero() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertIfMintBreaksHealthFactor() public {
        (, uint256 excessMintAmount) = dscEngine.getAccountInformation(user);

        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__TransactionBreaksHealthFactor.selector);
        dscEngine.mintDsc(excessMintAmount);
        vm.stopPrank();
    }
}
