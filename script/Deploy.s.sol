// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {ContentFactory} from "../src/ContentFactory.sol";
import {SaleFactory} from "../src/SaleFactory.sol";
import {RewarderFactory} from "../src/RewarderFactory.sol";
import {WaveFront} from "../src/WaveFront.sol";
import {WaveFrontRouter} from "../src/WaveFrontRouter.sol";
import {WaveFrontMulticall} from "../src/WaveFrontMulticall.sol";

contract Deploy is Script {
    MockUSDC public usdc;
    TokenFactory public tokenFactory;
    ContentFactory public contentFactory;
    SaleFactory public saleFactory;
    RewarderFactory public rewarderFactory;
    WaveFront public waveFront;
    WaveFrontRouter public waveFrontRouter;
    WaveFrontMulticall public waveFrontMulticall;

    function run() public {
        vm.startBroadcast();
        usdc = new MockUSDC();
        tokenFactory = new TokenFactory();
        contentFactory = new ContentFactory();
        saleFactory = new SaleFactory();
        rewarderFactory = new RewarderFactory();
        waveFront = new WaveFront(
            address(usdc),
            address(tokenFactory),
            address(saleFactory),
            address(contentFactory),
            address(rewarderFactory)
        );
        waveFrontRouter = new WaveFrontRouter(address(waveFront));
        waveFrontMulticall = new WaveFrontMulticall(address(waveFront));
        vm.stopBroadcast();
    }
}
