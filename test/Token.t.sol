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

    function testRevert_Token_BuyBeforeOpen() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");

        Token token = Token(tokenFactory.lastToken());

        address user = address(0x123);

        usdc.mint(user, 100e6);

        vm.prank(user);
        usdc.approve(address(token), 100e6);

        vm.prank(user);
        vm.expectRevert("Token__MarketClosed()");
        token.buy(100e6, 0, block.timestamp + 3600, user, address(0));
    }

    function test_Token_BuyBeforeOpenAsSale(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        address sale = saleFactory.lastSale();

        usdc.mint(sale, amount);

        vm.prank(sale);
        usdc.approve(address(token), amount);

        vm.prank(sale);
        token.buy(amount, 0, block.timestamp + 3600, sale, address(0));
    }

    function test_Token_BuyAfterOpen(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);

        usdc.mint(user1, amount);

        vm.prank(user1);
        usdc.approve(address(sale), amount);

        vm.prank(user1);
        sale.contribute(user1, amount);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        usdc.mint(user2, 100e6);

        vm.prank(user2);
        usdc.approve(address(token), 100e6);

        vm.prank(user2);
        token.buy(100e6, 0, block.timestamp + 3600, user2, address(0));
    }

    function testFuzz_Token_BuyAfterOpen(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);

        usdc.mint(user1, 100e6);

        vm.prank(user1);
        usdc.approve(address(sale), 100e6);

        vm.prank(user1);
        sale.contribute(user1, 100e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        usdc.mint(user2, amount);

        vm.prank(user2);
        usdc.approve(address(token), amount);

        vm.prank(user2);
        token.buy(amount, 0, block.timestamp + 3600, user2, address(0));
    }

    function testFuzzRevert_Token_BuyRevertSlippage(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);

        usdc.mint(user1, 100e6);

        vm.prank(user1);
        usdc.approve(address(sale), 100e6);

        vm.prank(user1);
        sale.contribute(user1, 100e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        usdc.mint(user2, amount);

        vm.prank(user2);
        usdc.approve(address(token), amount);

        vm.prank(user2);
        vm.expectRevert("Token__Slippage()");
        token.buy(amount, type(uint256).max, block.timestamp + 3600, user2, address(0));
    }

    function testRevert_Token_BuyZeroInput() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);

        usdc.mint(user1, 100e6);

        vm.prank(user1);
        usdc.approve(address(sale), 100e6);

        vm.prank(user1);
        sale.contribute(user1, 100e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        vm.prank(user2);
        vm.expectRevert("Token__ZeroInput()");
        token.buy(0, 0, block.timestamp + 3600, user2, address(0));
    }

    function testFuzzRevert_Token_BuyExpired(uint256 deadline) public {
        vm.warp(block.timestamp + 100 weeks);

        vm.assume(deadline > 0 && deadline < block.timestamp);
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);

        usdc.mint(user1, 100e6);

        vm.prank(user1);
        usdc.approve(address(sale), 100e6);

        vm.prank(user1);
        sale.contribute(user1, 100e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        usdc.mint(user2, 100e6);

        vm.prank(user2);
        usdc.approve(address(token), 100e6);

        vm.prank(user2);
        vm.expectRevert("Token__Expired()");
        token.buy(100e6, 0, deadline, user2, address(0));
    }
}
