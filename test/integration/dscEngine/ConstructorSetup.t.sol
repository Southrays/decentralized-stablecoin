// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";

contract ConstructorSetup is Test {
    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    DeployDsc deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;

    address public wEth;
    address public wBtc;
    address public wEthUsdPriceFeed;
    address public wBtcUsdPriceFeed;

    address[] public tokenAddresses = [wEth, wBtc];
    address[] public priceFeedsAddresses = [wEth, wBtc];
    address[] public oneTokenAddresses = [wEth];
    address[] public onePriceFeedsAddresses = [wEthUsdPriceFeed];

    //////////////////////////
    /////     SetUp     /////
    ////////////////////////
    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();

        (wEthUsdPriceFeed, wBtcUsdPriceFeed, wEth, wBtc,) = helperConfig.activeNetworkConfig();
    }

    ////////////////////////////////////////////
    /////     Constructor Setup Tests     /////
    //////////////////////////////////////////
    function testConstructorSetup() public {
        DecentralizedStablecoin sampleDsc = new DecentralizedStablecoin();
        DSCEngine sampleDscEngine = new DSCEngine(tokenAddresses, priceFeedsAddresses, address(sampleDsc));

        DecentralizedStablecoin dscEngineToken = sampleDscEngine.i_dsc();

        assertEq(address(sampleDsc), address(dscEngineToken));
    }

    function testRevertIfTokenAndPriceFeedLengthAreNotTheSame() public {
        vm.expectRevert(DSCEngine.DSCEngine__TokensLengthAndPriceFeedsLengthMismatch.selector);
        new DSCEngine(tokenAddresses, onePriceFeedsAddresses, address(dsc));

        vm.expectRevert(DSCEngine.DSCEngine__TokensLengthAndPriceFeedsLengthMismatch.selector);
        new DSCEngine(oneTokenAddresses, priceFeedsAddresses, address(dsc));
    }
}
