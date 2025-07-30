// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {Token, TokenFactory} from "../src/TokenFactory.sol";
import {Sale, SaleFactory} from "../src/SaleFactory.sol";
import {Content, ContentFactory} from "../src/ContentFactory.sol";
import {Rewarder, RewarderFactory} from "../src/RewarderFactory.sol";
import {WaveFront} from "../src/WaveFront.sol";
import {WaveFrontRouter} from "../src/WaveFrontRouter.sol";
import {WaveFrontMulticall} from "../src/WaveFrontMulticall.sol";

contract IntegrationTest is Test {
    Deploy public deploy;
    MockUSDC public usdc;
    TokenFactory public tokenFactory;
    SaleFactory public saleFactory;
    ContentFactory public contentFactory;
    RewarderFactory public rewarderFactory;
    WaveFront public waveFront;
    WaveFrontRouter public router;
    WaveFrontMulticall public multicall;

    function setUp() public {
        deploy = new Deploy();
        deploy.run();

        usdc = deploy.usdc();
        tokenFactory = deploy.tokenFactory();
        saleFactory = deploy.saleFactory();
        contentFactory = deploy.contentFactory();
        rewarderFactory = deploy.rewarderFactory();
        waveFront = deploy.waveFront();
        router = deploy.waveFrontRouter();
        multicall = deploy.waveFrontMulticall();
    }

    function test_Integration(
        uint256 user1ContributeAmount,
        uint256 user2ContributeAmount,
        uint256 user3ContributeAmount,
        uint256 user1BuyAmount1,
        uint256 user1BuyAmount2,
        uint256 user2BuyAmount1,
        uint256 user1SellAmount1,
        uint256 user1BuyAmount4,
        uint256 user1Borrow1,
        uint256 user1Transfer1,
        uint256 user1Repay1,
        uint256 user1Transfer2,
        uint256 user3BuyAmount1,
        uint256 user1Heal1,
        uint256 user1Heal2,
        uint256 user1Burn1
    ) public {
        address user1 = address(0x101);
        address user2 = address(0x102);
        address user3 = address(0x103);
        address user4 = address(0x104);

        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address multisig = address(0x105);
        address treasury = address(0x106);

        // user1 creates wft
        vm.prank(user1);
        Token wft1 = Token(router.createToken("Test1", "TEST1", "ipfs://test1", false));
        WaveFrontMulticall.Data memory data = multicall.getData(address(wft1), user1);

        // user1 contributes to sale
        vm.assume(user1ContributeAmount > 1000 && user1ContributeAmount < 1_000_000_000_000_000_000);
        usdc.mint(user1, user1ContributeAmount);
        vm.prank(user1);
        usdc.approve(address(router), user1ContributeAmount);
        vm.prank(user1);
        router.contribute(address(wft1), user1ContributeAmount);
        data = multicall.getData(address(wft1), user1);

        // user2 contributes to sale
        vm.assume(user2ContributeAmount > 1000 && user2ContributeAmount < 1_000_000_000_000_000_000);
        usdc.mint(user2, user2ContributeAmount);
        vm.prank(user2);
        usdc.approve(address(router), user2ContributeAmount);
        vm.prank(user2);
        router.contribute(address(wft1), user2ContributeAmount);
        data = multicall.getData(address(wft1), user2);

        // user2 contributes to sale again
        vm.assume(user2ContributeAmount > 1000 && user2ContributeAmount < 1_000_000_000_000_000_000);
        usdc.mint(user2, user2ContributeAmount);
        vm.prank(user2);
        usdc.approve(address(router), user2ContributeAmount);
        vm.prank(user2);
        router.contribute(address(wft1), user2ContributeAmount);
        data = multicall.getData(address(wft1), user2);

        // user3 contributes to sale
        vm.assume(user3ContributeAmount > 1000 && user3ContributeAmount < 1_000_000_000_000_000_000);
        usdc.mint(user3, user3ContributeAmount);
        vm.prank(user3);
        usdc.approve(address(router), user3ContributeAmount);
        vm.prank(user3);
        router.contribute(address(wft1), user3ContributeAmount);
        data = multicall.getData(address(wft1), user3);

        // user1 redeems wft and fails cause sale is in progress
        vm.prank(user1);
        vm.expectRevert("Sale__Open()");
        router.redeem(address(wft1));

        // warp time to sale end
        vm.warp(block.timestamp + 10000);
        data = multicall.getData(address(wft1), user1);
        data = multicall.getData(address(wft1), user4);

        // user1 redeems wft contribution and opens sale
        vm.prank(user1);
        router.redeem(address(wft1));
        data = multicall.getData(address(wft1), user1);

        // user1 redeems wft contribution but fails
        vm.prank(user1);
        vm.expectRevert("Sale__ZeroQuoteRaw()");
        router.redeem(address(wft1));

        // user4 redeems wft contribution but fails
        vm.prank(user4);
        vm.expectRevert("Sale__ZeroQuoteRaw()");
        router.redeem(address(wft1));

        // user2 redeems wft contribution
        vm.prank(user2);
        router.redeem(address(wft1));
        data = multicall.getData(address(wft1), user2);

        // user4 tries to contribute and fails
        usdc.mint(user4, 1e6);
        vm.prank(user4);
        usdc.approve(address(router), 1e6);
        vm.prank(user4);
        vm.expectRevert("Sale__Closed()");
        router.contribute(address(wft1), 1e6);
        vm.prank(user4);
        usdc.transfer(address(0x9999999999999999999999999999999999999999), 1e6);

        // user1 buys wft1
        vm.assume(user1BuyAmount1 > 1000 && user1BuyAmount1 < 1_000_000_000_000_000_000);
        (uint256 tokenAmtOut, uint256 slippage, uint256 minTokenAmtOut, uint256 autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), 0, 9800);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), user1BuyAmount1, 9800);
        uint256 quoteRawIn;
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyTokenOut(address(wft1), user1BuyAmount1, 9800);
        console.log("quoteRawIn", user1BuyAmount1);
        console.log("tokenAmtOut", tokenAmtOut);
        console.log("slippage", slippage);
        console.log("minTokenAmtOut", minTokenAmtOut);
        console.log("autoMinTokenAmtOut", autoMinTokenAmtOut);
        usdc.mint(user1, user1BuyAmount1);
        vm.prank(user1);
        usdc.approve(address(router), user1BuyAmount1);
        vm.prank(user1);
        router.buy(address(wft1), address(0), user1BuyAmount1, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user1 buys wft again
        vm.assume(user1BuyAmount2 > 1000 && user1BuyAmount2 < 1_000_000_000_000_000_000);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), user1BuyAmount2, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyTokenOut(address(wft1), user1BuyAmount2, 9800);
        usdc.mint(user1, user1BuyAmount2);
        vm.prank(user1);
        usdc.approve(address(router), user1BuyAmount2);
        vm.prank(user1);
        router.buy(address(wft1), address(0), user1BuyAmount2, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user1 sells all wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        uint256 quoteRawOut;
        uint256 minQuoteRawOut;
        uint256 autoMinQuoteRawOut;
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), user1BuyAmount2, 9800);
        vm.prank(user1);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user1);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user1 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 1000e6, 9000);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 1000e6, 9000);
        usdc.mint(user1, 1000e6);
        vm.prank(user1);
        usdc.approve(address(router), 1000e6);
        vm.prank(user1);
        router.buy(address(wft1), address(0), 1000e6, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user2 buys wft1
        vm.assume(user2BuyAmount1 > 1000 && user2BuyAmount1 < 1_000_000_000_000_000_000);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), user2BuyAmount1, 6000);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyTokenOut(address(wft1), user2BuyAmount1, 9990);
        usdc.mint(user2, user2BuyAmount1);
        vm.prank(user2);
        usdc.approve(address(router), user2BuyAmount1);
        vm.prank(user2);
        router.buy(address(wft1), address(0), user2BuyAmount1, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user3 redeems wft1
        vm.prank(user3);
        router.redeem(address(wft1));
        data = multicall.getData(address(wft1), user3);

        // user1 sells some wft1
        data = multicall.getData(address(wft1), user1);
        vm.assume(user1SellAmount1 > 1000 && user1SellAmount1 < data.accountTokenBalance);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), user1SellAmount1, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), user1SellAmount1 / 1e12, 9800);
        vm.prank(user1);
        wft1.approve(address(router), user1SellAmount1);
        vm.prank(user1);
        router.sell(address(wft1), address(0), user1SellAmount1, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user1 sells all wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user1);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user1);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user2 sells all wft1
        data = multicall.getData(address(wft1), user2);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user2);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user2);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user3 sells all wft1
        data = multicall.getData(address(wft1), user3);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user3);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user3);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user3);

        // user1 buys wft1
        vm.assume(user1BuyAmount4 > 1000 && user1BuyAmount4 < 1_000_000_000_000_000_000);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), user1BuyAmount4, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyTokenOut(address(wft1), user1BuyAmount4, 9800);
        usdc.mint(user1, user1BuyAmount4);
        vm.prank(user1);
        usdc.approve(address(router), user1BuyAmount4);
        vm.prank(user1);
        router.buy(address(wft1), address(0), user1BuyAmount4, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user1 borrows against wft1
        uint256 credit = wft1.getAccountCredit(user1);
        vm.assume(user1Borrow1 > 0 && user1Borrow1 <= credit);
        vm.prank(user1);
        wft1.borrow(user1, user1Borrow1);
        data = multicall.getData(address(wft1), user1);

        // user1 transfers some wft1 to user2
        uint256 maxTransferrable = wft1.getAccountTransferrable(user1);
        vm.assume(user1Transfer1 > 0 && user1Transfer1 <= maxTransferrable);
        vm.prank(user1);
        wft1.transfer(user2, user1Transfer1);
        data = multicall.getData(address(wft1), user1);
        data = multicall.getData(address(wft1), user2);

        // user 1 repays some debt
        uint256 debt = wft1.account_DebtRaw(user1);
        vm.assume(user1Repay1 > 0 && user1Repay1 <= debt);
        vm.prank(user1);
        usdc.approve(address(wft1), user1Repay1);
        vm.prank(user1);
        wft1.repay(user1, user1Repay1);
        data = multicall.getData(address(wft1), user1);

        // user1 transfers some wft1 to user2
        maxTransferrable = wft1.getAccountTransferrable(user1);
        vm.assume(user1Transfer2 > 0 && user1Transfer2 <= maxTransferrable);
        vm.prank(user1);
        wft1.transfer(user2, user1Transfer2);
        data = multicall.getData(address(wft1), user1);
        data = multicall.getData(address(wft1), user2);

        // user 1 repays all debt
        debt = wft1.account_DebtRaw(user1);
        if (debt > 0) {
            vm.prank(user1);
            usdc.approve(address(wft1), debt);
            vm.prank(user1);
            wft1.repay(user1, debt);
            data = multicall.getData(address(wft1), user1);
        }

        // user1 transfers all wft1 to user2
        uint256 wft1Balance = wft1.balanceOf(user1);
        vm.prank(user1);
        wft1.transfer(user2, wft1Balance);
        data = multicall.getData(address(wft1), user1);
        data = multicall.getData(address(wft1), user2);

        // user2 sells all wft1
        data = multicall.getData(address(wft1), user2);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user2);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user2);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user1 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 10000e6, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 10000e6, 9800);
        usdc.mint(user1, 10000e6);
        vm.prank(user1);
        usdc.approve(address(router), 10000e6);
        vm.prank(user1);
        router.buy(address(wft1), address(0), 10000e6, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user2 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 10000e6, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 10000e6, 9800);
        usdc.mint(user2, 10000e6);
        vm.prank(user2);
        usdc.approve(address(router), 10000e6);
        vm.prank(user2);
        router.buy(address(wft1), address(0), 10000e6, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user3 buys wft1
        vm.assume(user3BuyAmount1 > 1000 && user3BuyAmount1 < 1_000_000_000_000_000_000);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyQuoteIn(address(wft1), user3BuyAmount1, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.buyTokenOut(address(wft1), user3BuyAmount1, 9800);
        usdc.mint(user3, user3BuyAmount1);
        vm.prank(user3);
        usdc.approve(address(router), user3BuyAmount1);
        vm.prank(user3);
        router.buy(address(wft1), address(0), user3BuyAmount1, 0, 0);
        data = multicall.getData(address(wft1), user3);

        // user1 heals with usdc
        vm.assume(user1Heal1 > 0 && user1Heal1 < 1_000_000_000_000_000_000);
        usdc.mint(user1, user1Heal1);
        vm.prank(user1);
        usdc.approve(address(wft1), user1Heal1);
        vm.prank(user1);
        wft1.heal(user1Heal1);
        data = multicall.getData(address(wft1), user1);

        // user3 sells all wft1
        data = multicall.getData(address(wft1), user3);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user3);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user3);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user3);

        // user1 heals with usdc
        vm.assume(user1Heal2 > 0 && user1Heal2 < 1_000_000_000_000_000_000);
        usdc.mint(user1, user1Heal2);
        vm.prank(user1);
        usdc.approve(address(wft1), user1Heal2);
        vm.prank(user1);
        wft1.heal(user1Heal2);
        data = multicall.getData(address(wft1), user1);

        // user1 burns wft1
        uint256 balanceWft1 = wft1.balanceOf(user1);
        vm.assume(user1Burn1 > 0 && user1Burn1 <= balanceWft1);
        vm.prank(user1);
        wft1.burn(user1Burn1);
        data = multicall.getData(address(wft1), user1);

        // set wavefront treasury to treasury
        vm.prank(owner);
        waveFront.setTreasury(treasury);
        assertEq(waveFront.treasury(), treasury);

        // transfer ownership to multisig
        vm.prank(owner);
        waveFront.transferOwnership(multisig);
        assertEq(waveFront.owner(), multisig);

        // user1 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 10000e6, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 10000e6, 9800);
        usdc.mint(user1, 10000e6);
        vm.prank(user1);
        usdc.approve(address(router), 10000e6);
        vm.prank(user1);
        router.buy(address(wft1), user2, 10000e6, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user2 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 10000e6, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 10000e6, 9800);
        usdc.mint(user2, 10000e6);
        vm.prank(user2);
        usdc.approve(address(router), 10000e6);
        vm.prank(user2);
        router.buy(address(wft1), user3, 10000e6, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user3 buys wft1
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyQuoteIn(address(wft1), 10000e6, 9800);
        (quoteRawIn, slippage, minTokenAmtOut, autoMinTokenAmtOut) = multicall.buyTokenOut(address(wft1), 10000e6, 9800);
        usdc.mint(user3, 10000e6);
        vm.prank(user3);
        usdc.approve(address(router), 10000e6);
        vm.prank(user3);
        router.buy(address(wft1), user1, 10000e6, 0, 0);
        data = multicall.getData(address(wft1), user3);

        // user1 sells all wft1
        data = multicall.getData(address(wft1), user1);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user1);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user1);
        router.sell(address(wft1), user2, data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user1);

        // user2 sells all wft1
        data = multicall.getData(address(wft1), user2);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user2);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user2);
        router.sell(address(wft1), user3, data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user2);

        // user3 sells all wft1
        data = multicall.getData(address(wft1), user3);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(user3);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(user3);
        router.sell(address(wft1), treasury, data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), user3);

        // treasury sells all wft1
        data = multicall.getData(address(wft1), treasury);
        (tokenAmtOut, slippage, minTokenAmtOut, autoMinTokenAmtOut) =
            multicall.sellTokenIn(address(wft1), data.accountTokenBalance, 9800);
        (quoteRawOut, slippage, minQuoteRawOut, autoMinQuoteRawOut) =
            multicall.sellQuoteOut(address(wft1), data.accountTokenBalance / 1e12, 9800);
        vm.prank(treasury);
        wft1.approve(address(router), data.accountTokenBalance);
        vm.prank(treasury);
        router.sell(address(wft1), address(0), data.accountTokenBalance, 0, 0);
        data = multicall.getData(address(wft1), treasury);

        // user1 creates content
        vm.prank(user1);
        router.createContent(address(wft1), "https://ipfs.com/1");
        data = multicall.getData(address(wft1), user1);
        vm.assertTrue(multicall.contentPrice(address(wft1), 1) == 1e6);

        // user2 curates content
        uint256 contentPrice = multicall.contentPrice(address(wft1), 1);
        usdc.mint(user2, contentPrice);
        vm.prank(user2);
        usdc.approve(address(router), contentPrice);
        vm.prank(user2);
        router.curateContent(address(wft1), 1);
        data = multicall.getData(address(wft1), user2);
        vm.warp(block.timestamp + 1 days);

        // user3 curates content
        contentPrice = multicall.contentPrice(address(wft1), 1);
        usdc.mint(user3, contentPrice);
        vm.prank(user3);
        usdc.approve(address(router), contentPrice);
        vm.prank(user3);
        router.curateContent(address(wft1), 1);
        data = multicall.getData(address(wft1), user3);
        vm.warp(block.timestamp + 1 days);

        //user1 curates content
        contentPrice = multicall.contentPrice(address(wft1), 1);
        usdc.mint(user1, contentPrice);
        vm.prank(user1);
        usdc.approve(address(router), contentPrice);
        vm.prank(user1);
        router.curateContent(address(wft1), 1);
        data = multicall.getData(address(wft1), user1);
        vm.warp(block.timestamp + 1 days);

        // user1 claims rewards
        vm.prank(user1);
        router.getContentReward(address(wft1));
        data = multicall.getData(address(wft1), user1);

        // user1 claims rewards
        vm.prank(user1);
        router.getContentReward(address(wft1));
        data = multicall.getData(address(wft1), user1);

        // user2 claims rewards
        vm.prank(user2);
        router.getContentReward(address(wft1));
        data = multicall.getData(address(wft1), user2);

        // user3 claims rewards
        vm.prank(user3);
        router.getContentReward(address(wft1));
        data = multicall.getData(address(wft1), user3);

        // user4 notifies reward amount
        vm.warp(block.timestamp + 7 days);
        usdc.mint(user4, 10000e6);
        vm.prank(user4);
        usdc.approve(address(router), 10000e6);
        vm.prank(user4);
        router.notifyContentRewardAmount(address(wft1), address(usdc), 10000e6);
        data = multicall.getData(address(wft1), user4);

        // owner withdraws stuck tokens
        usdc.mint(address(router), 1e6);
        vm.prank(owner);
        router.withdrawStuckTokens(address(usdc), multisig);
    }
}
