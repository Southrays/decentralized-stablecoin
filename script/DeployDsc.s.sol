// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDsc is Script {
    //////////////////////////////
    /////     Variables     /////
    ////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStablecoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address wEthUsdPriceFeed, address wBtcUsdPriceFeed, address wEth, address wBtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [wEth, wBtc];
        priceFeedAddresses = [wEthUsdPriceFeed, wBtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStablecoin dsc = new DecentralizedStablecoin();
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();

        return (DecentralizedStablecoin(dsc), DSCEngine(dscEngine), helperConfig);
    }
}
