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
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Token token = Token(tokenFactory.lastToken());
        Content content = Content(contentFactory.lastContent());

        assertTrue(address(content) == token.content());
        assertTrue(content.rewarder() == rewarderFactory.lastRewarder());
        assertTrue(content.token() == address(token));
        assertTrue(content.quote() == address(usdc));
        assertTrue(content.nextTokenId() == 0);
    }

    function testRevert_Content_CreateAccountZero() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());

        vm.expectRevert("Content__ZeroTo()");
        content.create(address(0), "ipfs://content1");
    }

    function test_Content_Create() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
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

    function testRevert_Content_CurateMarketClosed() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());

        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);
        address owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x123));

        uint256 nextPrice = content.getNextPrice(1);
        assertTrue(nextPrice == 1e6);

        usdc.mint(address(0x456), 1e6);

        vm.prank(address(0x456));
        usdc.approve(address(content), 1e6);

        vm.prank(address(0x456));
        vm.expectRevert("Token__InvalidShift()");
        content.curate(address(0x456), 1);

        nextTokenId = content.nextTokenId();
        price = content.id_Price(1);
        creator = content.id_Creator(1);
        owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x123));

        nextPrice = content.getNextPrice(1);
        assertTrue(nextPrice == 1e6);
    }

    function test_Content_Curate() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());
        Sale sale = Sale(saleFactory.lastSale());

        usdc.mint(address(0x789), 1e6);

        vm.prank(address(0x789));
        usdc.approve(address(sale), 1e6);

        vm.prank(address(0x789));
        sale.contribute(address(0x789), 1e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);
        address owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x123));

        uint256 nextPrice = content.getNextPrice(1);
        assertTrue(nextPrice == 1e6);

        usdc.mint(address(0x456), 1e6);

        vm.prank(address(0x456));
        usdc.approve(address(content), 1e6);

        vm.prank(address(0x456));
        content.curate(address(0x456), 1);

        nextTokenId = content.nextTokenId();
        price = content.id_Price(1);
        creator = content.id_Creator(1);
        owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 1e6);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x456));

        nextPrice = content.getNextPrice(1);
        assertTrue(nextPrice == (price * 11) / 10 + 1e6);
    }

    function test_Content_CurateManyTimes() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());
        // Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());

        usdc.mint(address(0x789), 1e6);

        vm.prank(address(0x789));
        usdc.approve(address(sale), 1e6);

        vm.prank(address(0x789));
        sale.contribute(address(0x789), 1e6);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);
        address owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x123));

        for (uint256 i = 0; i < 200; i++) {
            address user = address(uint160(i + 1));
            uint256 lastPrice = content.id_Price(1);
            price = content.getNextPrice(1);
            // console.log("Curate Count: ", i);
            // console.log("Curate Price: $", price / 1e6);
            // console.log("Token Price: $", Token(token).getMarketPrice() / 1e18);
            // console.log();
            assertTrue(price == (lastPrice * 11) / 10 + 1e6);

            usdc.mint(user, price);

            vm.prank(user);
            usdc.approve(address(content), price);

            vm.prank(user);
            content.curate(user, 1);

            uint256 nextPrice = content.getNextPrice(1);
            creator = content.id_Creator(1);
            owner = content.ownerOf(1);

            assertTrue(nextPrice == (price * 11) / 10 + 1e6);
            assertTrue(creator == address(0x123));
            assertTrue(owner == user);
        }
    }

    function test_Content_Distribute(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 1_000_000_000_000_000_000);
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());
        Token token = Token(tokenFactory.lastToken());
        Sale sale = Sale(saleFactory.lastSale());
        Rewarder rewarder = Rewarder(rewarderFactory.lastRewarder());

        content.distribute();
        uint256 tokenBalanceContent = token.balanceOf(address(content));
        uint256 tokenBalanceRewarder = token.balanceOf(address(rewarder));
        uint256 usdcBalanceContent = usdc.balanceOf(address(content));
        uint256 usdcBalanceRewarder = usdc.balanceOf(address(rewarder));

        assertTrue(tokenBalanceContent == 0);
        assertTrue(tokenBalanceRewarder == 0);
        assertTrue(usdcBalanceContent == 0);
        assertTrue(usdcBalanceRewarder == 0);

        usdc.mint(address(0x123), amount);

        vm.prank(address(0x123));
        usdc.approve(address(sale), amount);

        vm.prank(address(0x123));
        sale.contribute(address(0x123), amount);

        vm.warp(block.timestamp + 2 hours + 60 seconds);

        sale.openMarket();

        sale.redeem(address(0x123));

        usdc.mint(address(content), amount);

        uint256 userTokenBalance = token.balanceOf(address(0x123));

        vm.prank(address(0x123));
        token.transfer(address(content), userTokenBalance);

        uint256 tokenToDistro = token.balanceOf(address(content));
        uint256 usdcToDistro = usdc.balanceOf(address(content));

        content.distribute();

        tokenBalanceContent = token.balanceOf(address(content));
        tokenBalanceRewarder = token.balanceOf(address(rewarder));
        usdcBalanceContent = usdc.balanceOf(address(content));
        usdcBalanceRewarder = usdc.balanceOf(address(rewarder));

        uint256 duration = rewarder.duration();

        if (tokenToDistro > duration) {
            assertTrue(tokenBalanceContent == 0);
            assertTrue(tokenBalanceRewarder > 0);
        } else {
            assertTrue(tokenBalanceContent > 0);
            assertTrue(tokenBalanceRewarder == 0);
        }

        if (usdcToDistro > duration) {
            assertTrue(usdcBalanceContent == 0);
            assertTrue(usdcBalanceRewarder > 0);
        } else {
            assertTrue(usdcBalanceContent > 0);
            assertTrue(usdcBalanceRewarder == 0);
        }
    }

    function testRevert_Content_Transfer() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());

        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);
        address owner = content.ownerOf(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));
        assertTrue(owner == address(0x123));

        vm.prank(address(0x123));
        vm.expectRevert("Content__TransferDisabled()");
        content.transferFrom(address(0x123), address(0x456), 1);

        owner = content.ownerOf(1);
        assertTrue(owner == address(0x123));

        vm.prank(address(0x123));
        vm.expectRevert("Content__TransferDisabled()");
        content.safeTransferFrom(address(0x123), address(0x456), 1);

        owner = content.ownerOf(1);
        assertTrue(owner == address(0x123));

        vm.prank(address(0x123));
        vm.expectRevert("Content__TransferDisabled()");
        content.safeTransferFrom(address(0x123), address(0x456), 1, "0x");

        owner = content.ownerOf(1);
        assertTrue(owner == address(0x123));
    }

    function test_Content_SupportsInterface() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());

        assertTrue(content.supportsInterface(0x80ac58cd));
        assertTrue(content.supportsInterface(0x5b5e139f));
        assertTrue(content.supportsInterface(0x780e9d63));
        assertTrue(content.supportsInterface(0x01ffc9a7));
        assertFalse(content.supportsInterface(0x12345678));
    }

    function test_Content_TokenURI() public {
        waveFront.create("Test1", "TEST1", "ipfs://test1", address(1), false);
        Content content = Content(contentFactory.lastContent());

        content.create(address(0x123), "ipfs://content1");
        string memory tokenURI1 = content.tokenURI(1);

        assertTrue(keccak256(bytes(tokenURI1)) == keccak256(bytes("ipfs://content1")));

        content.create(address(0x456), "ipfs://content2");
        string memory tokenURI2 = content.tokenURI(2);

        assertTrue(keccak256(bytes(tokenURI2)) == keccak256(bytes("ipfs://content2")));

        content.create(address(0x789), "ipfs://content3");
        string memory tokenURI3 = content.tokenURI(3);

        assertTrue(keccak256(bytes(tokenURI3)) == keccak256(bytes("ipfs://content3")));
    }

    function test_Content_CreatePrivate() public {
        address owner = address(0x123);
        waveFront.create("Test1", "TEST1", "ipfs://test1", owner, true);
        Content content = Content(contentFactory.lastContent());

        address user = address(0x456);

        vm.prank(user);
        vm.expectRevert("Content__NotCreator()");
        content.create(owner, "ipfs://content1");

        address[] memory creators = new address[](1);
        creators[0] = owner;
        vm.prank(owner);
        content.setCreators(creators, true);

        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        content.setCreators(creators, false);

        vm.prank(owner);
        content.create(user, "ipfs://content1");

        vm.prank(owner);
        content.create(owner, "ipfs://content2");

        creators[0] = user;
        vm.prank(owner);
        content.setCreators(creators, true);

        vm.prank(user);
        content.create(user, "ipfs://content3");
    }

    function test_Content_CreateMakePublic() public {
        address owner = address(0x722);
        waveFront.create("Test1", "TEST1", "ipfs://test1", owner, true);
        Content content = Content(contentFactory.lastContent());

        vm.prank(address(0x123));
        vm.expectRevert("Content__NotCreator()");
        content.create(address(0x123), "ipfs://content1");

        vm.prank(address(0x123));
        vm.expectRevert();
        content.setIsPrivate(false);

        vm.prank(owner);
        content.setIsPrivate(false);

        vm.prank(address(0x123));
        content.create(address(0x123), "ipfs://content1");
        uint256 nextTokenId = content.nextTokenId();
        uint256 price = content.id_Price(1);
        address creator = content.id_Creator(1);

        assertTrue(nextTokenId == 1);
        assertTrue(price == 0);
        assertTrue(creator == address(0x123));

        vm.prank(address(0x456));
        content.create(address(0x456), "ipfs://content2");
        nextTokenId = content.nextTokenId();
        price = content.id_Price(2);
        creator = content.id_Creator(2);

        assertTrue(nextTokenId == 2);
        assertTrue(price == 0);
        assertTrue(creator == address(0x456));

        vm.prank(address(0x789));
        content.create(address(0x789), "ipfs://content3");
        nextTokenId = content.nextTokenId();
        price = content.id_Price(3);
        creator = content.id_Creator(3);

        assertTrue(nextTokenId == 3);
        assertTrue(price == 0);
        assertTrue(creator == address(0x789));
    }

    function test_Content_AddRewardToken() public {
        address owner = address(0x123);
        waveFront.create("Test1", "TEST1", "ipfs://test1", owner, false);
        Content content = Content(contentFactory.lastContent());
        Rewarder rewarder = Rewarder(rewarderFactory.lastRewarder());

        MockToken mockToken = new MockToken();

        vm.expectRevert("Ownable: caller is not the owner");
        content.addReward(address(mockToken));

        vm.prank(owner);
        content.addReward(address(mockToken));

        assertTrue(rewarder.getRewardTokens().length == 3);
        assertTrue(rewarder.getRewardTokens()[2] == address(mockToken));
        assertTrue(rewarder.token_IsReward(address(mockToken)) == true);
    }
}
