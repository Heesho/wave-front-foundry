// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {Token, TokenFactory} from "../src/TokenFactory.sol";
import {Sale, SaleFactory} from "../src/SaleFactory.sol";
import {Content, ContentFactory} from "../src/ContentFactory.sol";
import {Rewarder, RewarderFactory} from "../src/RewarderFactory.sol";
import {WaveFront} from "../src/WaveFront.sol";

contract TokenTest is Test {
    Deploy public deploy;
    MockUSDC public usdc;
    TokenFactory public tokenFactory;
    SaleFactory public saleFactory;
    ContentFactory public contentFactory;
    RewarderFactory public rewarderFactory;
    WaveFront public waveFront;

    function setUp() public {
        deploy = new Deploy();
        deploy.run();

        usdc = deploy.usdc();
        tokenFactory = deploy.tokenFactory();
        saleFactory = deploy.saleFactory();
        contentFactory = deploy.contentFactory();
        rewarderFactory = deploy.rewarderFactory();
        waveFront = deploy.waveFront();
    }

    function test_Token_Constructor() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");

        Token token = Token(tokenFactory.lastToken());

        address quote = waveFront.quote();
        address sale = saleFactory.lastSale();
        address content = contentFactory.lastContent();
        address rewarder = rewarderFactory.lastRewarder();

        assertTrue(token.quote() == quote);
        assertTrue(token.sale() == sale);
        assertTrue(token.content() == content);
        assertTrue(token.rewarder() == rewarder);

        assertTrue(token.quoteDecimals() == 6);
        assertTrue(token.open() == false);

        assertTrue(token.maxSupply() == 1_000_000_000 * 1e18);
        assertTrue(token.reserveRealQuoteWad() == 0);
        assertTrue(token.reserveVirtQuoteWad() == 100_000 * 1e18);
        assertTrue(token.reserveTokenAmt() == 1_000_000_000 * 1e18);

        assertTrue(token.totalDebtRaw() == 0);
    }
}
