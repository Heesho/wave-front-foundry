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
        console.log("MockUSDC deployed at:", address(usdc));

        tokenFactory = new TokenFactory();
        console.log("TokenFactory deployed at:", address(tokenFactory));

        contentFactory = new ContentFactory();
        console.log("ContentFactory deployed at:", address(contentFactory));

        saleFactory = new SaleFactory();
        console.log("SaleFactory deployed at:", address(saleFactory));

        rewarderFactory = new RewarderFactory();
        console.log("RewarderFactory deployed at:", address(rewarderFactory));

        waveFront = new WaveFront(
            address(usdc),
            address(tokenFactory),
            address(saleFactory),
            address(contentFactory),
            address(rewarderFactory)
        );
        console.log("WaveFront deployed at:", address(waveFront));

        waveFrontRouter = new WaveFrontRouter(address(waveFront));
        console.log("Router deployed at:", address(waveFrontRouter));

        waveFrontMulticall = new WaveFrontMulticall(address(waveFront));
        console.log("Multicall deployed at:", address(waveFrontMulticall));

        vm.stopBroadcast();
    }
}
