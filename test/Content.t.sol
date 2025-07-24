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

contract ContentTest is Test {
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

    function test_Content_Constructor() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Token token = Token(tokenFactory.lastToken());
        Content content = Content(contentFactory.lastContent());

        assertTrue(address(content) == token.content());
        assertTrue(content.rewarder() == rewarderFactory.lastRewarder());
        assertTrue(content.token() == address(token));
        assertTrue(content.quote() == address(usdc));
        assertTrue(content.nextTokenId() == 0);
    }

    function testRevert_Content_CreateAccountZero() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Content content = Content(contentFactory.lastContent());

        vm.expectRevert("Content__ZeroTo()");
        content.create(address(0), "ipfs://content1");
    }

    function test_Content_Create() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1");
        Content content = Content(contentFactory.lastContent());

        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));

        content.create(address(0x456), "ipfs://content2");
        nextTokenId = content.nextTokenId();
        price = content.id_Price(2);
        creator = content.id_Creator(2);

        assertTrue(nextTokenId == 2);
        assertTrue(price == 0);
        assertTrue(creator == address(0x456));

        content.create(address(0x789), "ipfs://content3");
        nextTokenId = content.nextTokenId();
        price = content.id_Price(3);
        creator = content.id_Creator(3);

        assertTrue(nextTokenId == 3);
        assertTrue(price == 0);
        assertTrue(creator == address(0x789));
    }
}
