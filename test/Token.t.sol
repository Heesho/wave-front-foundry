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
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));

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
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));

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
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        Token token = Token(tokenFactory.lastToken());
        address sale = saleFactory.lastSale();

        usdc.mint(sale, amount);

        vm.prank(sale);
        usdc.approve(address(token), amount);

        vm.prank(sale);
        token.buy(amount, 0, block.timestamp + 3600, sale, address(0));
    }

    function testFuzz_Token_BuyAfterOpenConstant(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(100e6, 0, deadline, user2, address(0));
    }

    function testFuzz_Token_BuyAfterOpen(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        assertTrue(token.balanceOf(user2) == 0);

        usdc.mint(user2, amount);

        vm.prank(user2);
        usdc.approve(address(token), amount);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        assertTrue(token.balanceOf(user2) > 0);
    }

    function testFuzzRevert_Token_BuyRevertSlippage(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        vm.expectRevert("Token__Slippage()");
        token.buy(amount, type(uint256).max, deadline, user2, address(0));
    }

    function testRevert_Token_BuyZeroInput() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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
        vm.expectRevert("Token__MinTradeSize()");
        token.buy(0, 0, block.timestamp + 3600, user2, address(0));
    }

    function testFuzzRevert_Token_BuyExpired(uint256 deadline) public {
        vm.warp(block.timestamp + 100 weeks);

        vm.assume(deadline > 0 && deadline < block.timestamp);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

    function testFuzz_Token_BuyWithProvider(address provider, uint256 amount) public {
        vm.assume(provider != address(0));
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        assertTrue(usdc.balanceOf(provider) == 0);

        usdc.mint(user2, amount);

        vm.prank(user2);
        usdc.approve(address(token), amount);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, provider);

        assertTrue(usdc.balanceOf(provider) > 0);
    }

    function testFuzz_Token_Sell(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        uint256 tokenAmt = token.balanceOf(user2);

        vm.prank(user2);
        token.sell(tokenAmt, 0, deadline, user2, address(0));
    }

    function testFuzz_Token_SellWithProvider(address provider, uint256 amount) public {
        vm.assume(provider != address(0));
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        uint256 tokenAmt = token.balanceOf(user2);

        vm.prank(user2);
        token.sell(tokenAmt, 0, deadline, user2, provider);
    }

    function testFuzzRevert_Token_SellBelowTradeMin(uint256 amount, uint256 sellAmount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        vm.assume(sellAmount < 1000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.prank(user2);
        vm.expectRevert("Token__MinTradeSize()");
        token.sell(sellAmount, 0, deadline, user2, address(0));
    }

    function testRevertFuzz_Token_SellSlippage(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        uint256 tokenAmt = token.balanceOf(user2);

        vm.prank(user2);
        vm.expectRevert("Token__Slippage()");
        token.sell(tokenAmt, type(uint256).max, deadline, user2, address(0));
    }

    function testRevertFuzz_Token_SellExpired(uint256 deadline) public {
        vm.warp(block.timestamp + 100 weeks);
        vm.assume(deadline > 0 && deadline < block.timestamp);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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
        token.buy(100e6, 0, block.timestamp + 10000, user2, address(0));

        uint256 tokenAmt = token.balanceOf(user2);

        vm.prank(user2);
        vm.expectRevert("Token__Expired()");
        token.sell(tokenAmt, 0, deadline, user2, address(0));
    }

    function testFuzz_Token_BorrowMax(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditAmt = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditAmt);
        vm.assertTrue(token.totalDebtRaw() == creditAmt);
    }

    function testFuzz_Token_Borrow(uint256 amount, uint256 creditAmt) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.assume(creditAmt > 0 && creditAmt <= creditMax);

        vm.prank(user2);
        token.borrow(user2, creditAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditAmt);
        vm.assertTrue(token.totalDebtRaw() == creditAmt);
    }

    function testFuzzRevert_Token_BorrowOverCredit(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditAmt = token.getAccountCredit(user2);

        vm.prank(user2);
        vm.expectRevert("Token__CreditExceeded()");
        token.borrow(user2, creditAmt + amount);

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);
    }

    function testFuzz_Token_RepayMax(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.prank(user2);
        usdc.approve(address(token), creditMax);

        vm.prank(user2);
        token.repay(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);
    }

    function testFuzz_Token_Repay(uint256 amount, uint256 repayAmt) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.assume(repayAmt > 0 && repayAmt <= creditMax);

        vm.prank(user2);
        usdc.approve(address(token), repayAmt);

        vm.prank(user2);
        token.repay(user2, repayAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax - repayAmt);
        vm.assertTrue(token.totalDebtRaw() == creditMax - repayAmt);
    }

    function testRevert_Token_RepayZeroAmount() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        usdc.mint(user2, 1000e6);

        vm.prank(user2);
        usdc.approve(address(token), 1000e6);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(1000e6, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.prank(user2);
        vm.expectRevert("Token__ZeroInput()");
        token.repay(user2, 0);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);
    }

    function testFuzz_Token_TransferMax(uint256 amount, uint256 repayAmt) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);

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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.assume(repayAmt > 0 && repayAmt <= creditMax);

        vm.prank(user2);
        usdc.approve(address(token), repayAmt);

        vm.prank(user2);
        token.repay(user2, repayAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax - repayAmt);
        vm.assertTrue(token.totalDebtRaw() == creditMax - repayAmt);

        uint256 transferAmt = token.getAccountTransferrable(user2);

        vm.prank(user2);
        token.transfer(user3, transferAmt);

        vm.assertTrue(token.getAccountTransferrable(user2) == 0);
        vm.assertTrue(token.getAccountTransferrable(user3) == transferAmt);
    }

    function testFuzz_Token_Transfer(uint256 amount, uint256 repayAmt, uint256 transferAmt) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);

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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.assume(repayAmt > 0 && repayAmt <= creditMax);

        vm.prank(user2);
        usdc.approve(address(token), repayAmt);

        vm.prank(user2);
        token.repay(user2, repayAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax - repayAmt);
        vm.assertTrue(token.totalDebtRaw() == creditMax - repayAmt);

        vm.assume(transferAmt > 0 && transferAmt <= token.getAccountTransferrable(user2));

        vm.prank(user2);
        token.transfer(user3, transferAmt);

        vm.assertTrue(token.getAccountTransferrable(user3) == transferAmt);
    }

    function testFuzzRevert_Token_TransferOverTransferable(uint256 amount, uint256 repayAmt, uint256 transferAmt)
        public
    {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);

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

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(amount, 0, deadline, user2, address(0));

        vm.assertTrue(token.account_DebtRaw(user2) == 0);
        vm.assertTrue(token.totalDebtRaw() == 0);

        uint256 creditMax = token.getAccountCredit(user2);

        vm.prank(user2);
        token.borrow(user2, creditMax);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax);
        vm.assertTrue(token.totalDebtRaw() == creditMax);

        vm.assume(repayAmt > 0 && repayAmt <= creditMax);

        vm.prank(user2);
        usdc.approve(address(token), repayAmt);

        vm.prank(user2);
        token.repay(user2, repayAmt);

        vm.assertTrue(token.account_DebtRaw(user2) == creditMax - repayAmt);
        vm.assertTrue(token.totalDebtRaw() == creditMax - repayAmt);

        vm.assume(transferAmt > token.getAccountTransferrable(user2));

        vm.prank(user2);
        vm.expectRevert("Token__CollateralLocked()");
        token.transfer(user3, transferAmt);
    }

    function testFuzz_Token_Heal(uint256 buyAmt, uint256 healAmt) public {
        vm.assume(buyAmt > 1000 && buyAmt < 1_000_000_000_000_000_000);
        vm.assume(healAmt > 0 && healAmt < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        usdc.mint(user2, buyAmt);

        vm.prank(user2);
        usdc.approve(address(token), buyAmt);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(buyAmt, 0, deadline, user2, address(0));

        usdc.mint(user2, healAmt);

        vm.prank(user2);
        usdc.approve(address(token), healAmt);

        vm.prank(user2);
        token.heal(healAmt);
    }

    function testFuzz_Token_Burn(uint256 buyAmt, uint256 burnAmt) public {
        vm.assume(buyAmt > 1000 && buyAmt < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        usdc.mint(user2, buyAmt);

        vm.prank(user2);
        usdc.approve(address(token), buyAmt);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(buyAmt, 0, deadline, user2, address(0));

        vm.assume(burnAmt > 0 && burnAmt < token.balanceOf(user2));

        vm.prank(user2);
        token.burn(burnAmt);
    }

    function testFuzz_Token_Prices(uint256 buyAmt, uint256 burnAmt) public {
        vm.assume(buyAmt > 1000 && buyAmt < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
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

        usdc.mint(user2, buyAmt);

        vm.prank(user2);
        usdc.approve(address(token), buyAmt);

        uint256 deadline = block.timestamp + 10000;
        vm.prank(user2);
        token.buy(buyAmt, 0, deadline, user2, address(0));

        vm.assume(burnAmt > 0 && burnAmt < token.balanceOf(user2));

        vm.prank(user2);
        token.burn(burnAmt);

        uint256 marketPrice = token.getMarketPrice();
        uint256 floorPrice = token.getFloorPrice();

        vm.assertTrue(marketPrice >= floorPrice);
        vm.assertTrue(marketPrice > 0);
        vm.assertTrue(floorPrice > 0);
    }
}
