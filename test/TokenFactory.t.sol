// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {TokenFactory} from "../src/TokenFactory.sol";

contract TokenFactoryTest is Test {
    TokenFactory public tokenFactory;

    function setUp() public {
        Deploy deploy = new Deploy();
        deploy.run();

        tokenFactory = deploy.tokenFactory();
    }

    function test_LastToken() public view {
        address lastToken = tokenFactory.lastToken();
        assertEq(lastToken, address(0));
    }
}
