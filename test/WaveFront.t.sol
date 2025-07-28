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

contract WaveFrontTest is Test {
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

    function test_WaveFront_Constructor() public view {
        assertEq(waveFront.quote(), address(usdc));
        assertEq(waveFront.tokenFactory(), address(tokenFactory));
        assertEq(waveFront.saleFactory(), address(saleFactory));
        assertEq(waveFront.contentFactory(), address(contentFactory));
        assertEq(waveFront.rewarderFactory(), address(rewarderFactory));
    }

    function test_WaveFront_Create_Index() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        address lastToken = tokenFactory.lastToken();

        assertTrue(lastToken != address(0));
        assertTrue(waveFront.index() == 1);
        assertTrue(waveFront.index_Token(1) == lastToken);
        assertTrue(waveFront.index_Token(2) == address(0));
        assertTrue(waveFront.token_Index(lastToken) == 1);
        assertTrue(keccak256(bytes(waveFront.token_Uri(lastToken))) == keccak256(bytes("ipfs://test1")));
        assertTrue(keccak256(bytes(waveFront.token_Uri(address(0)))) == keccak256(bytes("")));

        waveFront.create("Test2", "TEST2", "ipfs://test2", address(0));
        address lastToken2 = tokenFactory.lastToken();

        assertTrue(lastToken2 != address(0));
        assertTrue(waveFront.index() == 2);
        assertTrue(waveFront.index_Token(1) == lastToken);
        assertTrue(waveFront.index_Token(2) == lastToken2);
        assertTrue(waveFront.index_Token(3) == address(0));
        assertTrue(waveFront.token_Index(lastToken2) == 2);
        assertTrue(keccak256(bytes(waveFront.token_Uri(lastToken2))) == keccak256(bytes("ipfs://test2")));
    }

    function test_WaveFront_Create_Token() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(0));
        address lastToken = tokenFactory.lastToken();
        address lastSale = saleFactory.lastSale();
        address lastContent = contentFactory.lastContent();
        address lastRewarder = rewarderFactory.lastRewarder();

        Token token = Token(lastToken);

        assertTrue(token.sale() == lastSale);
        assertTrue(token.content() == lastContent);
        assertTrue(token.rewarder() == lastRewarder);
        assertTrue(keccak256(bytes(token.name())) == keccak256(bytes("Test1")));
        assertTrue(keccak256(bytes(token.symbol())) == keccak256(bytes("TEST1")));
        assertTrue(token.reserveVirtQuoteWad() == 100_000 * 1e18);
        assertTrue(token.reserveRealQuoteWad() == 0);
        assertTrue(token.reserveTokenAmt() == 1_000_000_000 * 1e18);
        assertTrue(token.maxSupply() == 1_000_000_000 * 1e18);
        assertTrue(token.open() == false);
    }

    function test_WaveFront_Ownership() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address notOwner = address(0xBAD);
        address newOwner = address(0xBEEF);

        vm.prank(notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.transferOwnership(newOwner);
        assertTrue(waveFront.owner() == owner);
        assertTrue(waveFront.owner() != newOwner);

        vm.prank(owner);
        waveFront.transferOwnership(newOwner);
        assertTrue(waveFront.owner() == newOwner);
    }

    function test_WaveFront_SetTreasury() public {
        address defaultEOA = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address newTreasury = address(0x123);

        vm.prank(defaultEOA);
        waveFront.setTreasury(newTreasury);
        assertTrue(waveFront.treasury() == newTreasury);

        vm.prank(address(0xBAD));
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.setTreasury(address(0x222));
        assertTrue(waveFront.treasury() == newTreasury);
    }

    function test_WaveFront_SetTokenFactory() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address newTokenFactory = address(0x111);

        vm.prank(owner);
        waveFront.setTokenFactory(newTokenFactory);
        assertEq(waveFront.tokenFactory(), newTokenFactory);

        vm.prank(address(0xBAD));
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.setTokenFactory(address(0x222));
        assertEq(waveFront.tokenFactory(), newTokenFactory);
    }

    function test_WaveFront_SetSaleFactory() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address newSaleFactory = address(0x111);

        vm.prank(owner);
        waveFront.setSaleFactory(newSaleFactory);
        assertEq(waveFront.saleFactory(), newSaleFactory);

        vm.prank(address(0xBAD));
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.setSaleFactory(address(0x222));
        assertEq(waveFront.saleFactory(), newSaleFactory);
    }

    function test_WaveFront_SetContentFactory() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address newContentFactory = address(0x111);

        vm.prank(owner);
        waveFront.setContentFactory(newContentFactory);
        assertEq(waveFront.contentFactory(), newContentFactory);

        vm.prank(address(0xBAD));
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.setContentFactory(address(0x222));
        assertEq(waveFront.contentFactory(), newContentFactory);
    }

    function test_WaveFront_SetRewarderFactory() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        address newRewarderFactory = address(0x111);

        vm.prank(owner);
        waveFront.setRewarderFactory(newRewarderFactory);
        assertEq(waveFront.rewarderFactory(), newRewarderFactory);

        vm.prank(address(0xBAD));
        vm.expectRevert("Ownable: caller is not the owner");
        waveFront.setRewarderFactory(address(0x222));
        assertEq(waveFront.rewarderFactory(), newRewarderFactory);
    }

    function test_WaveFront_AddContentReward() public {
        address owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        waveFront.create("Test1", "TEST1", "https://test.com1", address(0));
        address lastToken = tokenFactory.lastToken();
        address rewarder = Token(lastToken).rewarder();

        vm.prank(owner);
        vm.expectRevert("Rewarder__RewardTokenAlreadyAdded()");
        waveFront.addContentReward(lastToken, address(usdc));

        MockToken mockToken = new MockToken();
        vm.prank(owner);
        waveFront.addContentReward(lastToken, address(mockToken));

        address rewardToken = Rewarder(rewarder).getRewardTokens()[2];
        assertTrue(rewardToken == address(mockToken));
    }
}
