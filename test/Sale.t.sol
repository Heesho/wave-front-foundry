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

contract SaleTest is Test {
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

    function test_Sale_Constructor() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");

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

    function testFuzz_Sale_Contribution(uint256 amount) public {
        vm.assume(amount > 0);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Sale sale = Sale(saleFactory.lastSale());

        address user = address(0x123);
        usdc.mint(user, amount);

        vm.prank(user);
        usdc.approve(address(sale), amount);

        vm.prank(user);
        sale.contribute(user, amount);
    }

    function test_Sale_OpenMarketNoContribution() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Sale sale = Sale(saleFactory.lastSale());

        vm.warp(block.timestamp + 2 hours);

        assertTrue(sale.ended() == false);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        assertTrue(sale.ended() == false);

        vm.expectRevert("Token__ZeroInput()");
        sale.openMarket();
        assertTrue(sale.ended() == false);
    }

    function testFuzz_Sale_OpenMarketWithContribution(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
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
        vm.assume(quoteAmount > 0 && quoteAmount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
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

        assertTrue(Token(token).balanceOf(user) == 0);
        sale.redeem(user);
        assertTrue(Token(token).balanceOf(user) > 0);

        vm.expectRevert("Sale__NothingToRedeem()");
        sale.redeem(user);

        vm.expectRevert("Sale__NothingToRedeem()");
        sale.redeem(address(0x456));
    }

    function testFuzz_Sale_ContributeAfterClose(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
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
