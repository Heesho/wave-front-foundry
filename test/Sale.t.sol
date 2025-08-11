// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {Token, TokenFactory} from "../src/TokenFactory.sol";
import {Sale, SaleFactory} from "../src/SaleFactory.sol";
import {Content, ContentFactory} from "../src/ContentFactory.sol";
import {Rewarder, RewarderFactory} from "../src/RewarderFactory.sol";
import {Core} from "../src/Core.sol";

contract SaleTest is Test {
    Deploy public deploy;
    MockUSDC public usdc;
    TokenFactory public tokenFactory;
    SaleFactory public saleFactory;
    ContentFactory public contentFactory;
    RewarderFactory public rewarderFactory;
    Core public core;

    function setUp() public {
        deploy = new Deploy();
        deploy.run();

        usdc = deploy.usdc();
        tokenFactory = deploy.tokenFactory();
        saleFactory = deploy.saleFactory();
        contentFactory = deploy.contentFactory();
        rewarderFactory = deploy.rewarderFactory();
        core = deploy.core();
    }

    function test_Sale_Constructor() public {
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);

        address lastSale = saleFactory.lastSale();
        address sale = Token(tokenFactory.lastToken()).sale();
        address token = Sale(lastSale).token();
        address quote = Sale(lastSale).quote();
        bool ended = Sale(lastSale).ended();
        uint256 totalTokenAmt = Sale(lastSale).totalTokenAmt();
        uint256 totalQuoteRaw = Sale(lastSale).totalQuoteRaw();

        assertTrue(lastSale == sale);
        assertTrue(token == tokenFactory.lastToken());
        assertTrue(quote == address(usdc));
        assertTrue(ended == false);
        assertTrue(totalTokenAmt == 0);
        assertTrue(totalQuoteRaw == 0);
    }

    function testRevert_Sale_ContributionZeroAmount() public {
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        vm.expectRevert("Sale__ZeroQuoteRaw()");
        sale.contribute(address(0x123), 0);
    }

    function testRevert_Sale_ContributionZeroAddress() public {
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        vm.expectRevert("Sale__ZeroTo()");
        sale.contribute(address(0), 100);
    }

    function test_Sale_OpenMarketNoContribution() public {
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        vm.warp(block.timestamp + 2 hours);

        assertTrue(sale.ended() == false);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        assertTrue(sale.ended() == false);

        vm.expectRevert("Token__MinTradeSize()");
        sale.openMarket();
        assertTrue(sale.ended() == false);
    }

    function testFuzz_Sale_Contribution(uint256 amount) public {
        vm.assume(amount > 1000);
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        address user = address(0x123);
        usdc.mint(user, amount);

        vm.prank(user);
        usdc.approve(address(sale), amount);

        vm.prank(user);
        sale.contribute(user, amount);

        console.log("End Time: ", sale.endTime());
        console.log("User Contribution: ", sale.account_QuoteRaw(user));
        console.log("Total Quote Raw: ", sale.totalQuoteRaw());
        console.log("Total Token Amt: ", sale.totalTokenAmt());
    }

    function testFuzz_Sale_OpenMarketWithContribution(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        address user = address(0x123);
        usdc.mint(user, amount);

        vm.prank(user);
        usdc.approve(address(sale), amount);

        vm.prank(user);
        sale.contribute(user, amount);

        vm.expectRevert("Sale__Open()");
        sale.openMarket();
        assertTrue(sale.ended() == false);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        assertTrue(sale.ended() == false);
        sale.openMarket();
        assertTrue(sale.ended() == true);

        vm.expectRevert("Sale__Closed()");
        sale.openMarket();
    }

    function testFuzz_Sale_ContributionOpenRedeem(uint256 quoteAmount) public {
        vm.assume(quoteAmount > 1000 && quoteAmount < 1_000_000_000_000_000_000);
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());
        Token token = Token(tokenFactory.lastToken());

        address user = address(0x123);
        usdc.mint(user, quoteAmount);

        vm.prank(user);
        usdc.approve(address(sale), quoteAmount);

        vm.prank(user);
        sale.contribute(user, quoteAmount);

        vm.expectRevert("Sale__Open()");
        sale.redeem(user);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        console.log("User Contribution: ", sale.account_QuoteRaw(user));
        console.log("Total Quote Raw: ", sale.totalQuoteRaw());
        console.log("Total Token Amt: ", sale.totalTokenAmt());

        assertTrue(Token(token).balanceOf(user) == 0);
        sale.redeem(user);
        assertTrue(Token(token).balanceOf(user) > 0);

        vm.expectRevert("Sale__ZeroQuoteRaw()");
        sale.redeem(user);

        vm.expectRevert("Sale__ZeroQuoteRaw()");
        sale.redeem(address(0x456));

        vm.expectRevert("Sale__ZeroWho()");
        sale.redeem(address(0));

        console.log("User Contribution: ", sale.account_QuoteRaw(user));
        console.log("Total Quote Raw: ", sale.totalQuoteRaw());
        console.log("Total Token Amt: ", sale.totalTokenAmt());
    }

    function testFuzz_Sale_ContributeAfterClose(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        core.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);
        usdc.mint(user1, amount);
        usdc.mint(user2, amount);

        vm.prank(user1);
        usdc.approve(address(sale), amount);

        vm.prank(user1);
        sale.contribute(user1, amount);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        assertTrue(sale.ended() == false);
        sale.openMarket();
        assertTrue(sale.ended() == true);

        vm.prank(user2);
        vm.expectRevert("Sale__Closed()");
        sale.contribute(user2, amount);
    }
}
