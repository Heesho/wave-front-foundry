// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {ContentFactory} from "../src/ContentFactory.sol";
import {SaleFactory} from "../src/SaleFactory.sol";
import {RewarderFactory} from "../src/RewarderFactory.sol";
import {Core} from "../src/Core.sol";
import {Router} from "../src/Router.sol";
import {Multicall} from "../src/Multicall.sol";

contract Deploy is Script {
    MockUSDC public usdc;
    TokenFactory public tokenFactory;
    ContentFactory public contentFactory;
    SaleFactory public saleFactory;
    RewarderFactory public rewarderFactory;
    Core public core;
    Router public router;
    Multicall public multicall;

    function run() public {
        vm.startBroadcast();

        usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));

        tokenFactory = new TokenFactory();
        console.log("TokenFactory deployed at:", address(tokenFactory));

        contentFactory = new ContentFactory();
        console.log("ContentFactory deployed at:", address(contentFactory));

        saleFactory = new SaleFactory();
        console.log("SaleFactory deployed at:", address(saleFactory));

        rewarderFactory = new RewarderFactory();
        console.log("RewarderFactory deployed at:", address(rewarderFactory));

        core = new Core(
            address(usdc),
            address(tokenFactory),
            address(saleFactory),
            address(contentFactory),
            address(rewarderFactory)
        );
        console.log("Core deployed at:", address(core));

        router = new Router(address(core));
        console.log("Router deployed at:", address(router));

        multicall = new Multicall(address(core));
        console.log("Multicall deployed at:", address(multicall));

        vm.stopBroadcast();
    }
}
