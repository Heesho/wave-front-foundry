// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IToken {
    function buy(uint256 quoteRawIn, uint256 minTokenAmtOut, uint256 deadline, address to, address provider)
        external
        returns (uint256 amountTokenOut);

    function openMarket() external;
}

contract Sale is ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant DURATION = 2 hours;

    address public immutable quote;
    address public immutable token;
    uint256 public immutable endTime;

    bool public ended = false;
    uint256 public totalTokenAmt;
    uint256 public totalQuoteRaw;
    mapping(address => uint256) public account_QuoteRaw;

    error Sale__ZeroInput();
    error Sale__Closed();
    error Sale__Open();
    error Sale__NothingToRedeem();

    event Sale__Contributed(address indexed who, address indexed to, uint256 quoteRaw);
    event Sale__MarketOpened(uint256 totalTokenAmt, uint256 totalQuoteRaw);
    event Sale__Redeemed(address indexed who, address indexed to, uint256 tokenAmt);

    constructor(address _token, address _quote) {
        token = _token;
        quote = _quote;
        endTime = block.timestamp + DURATION;
    }

    function contribute(address to, uint256 quoteRaw) external nonReentrant {
        if (quoteRaw == 0) revert Sale__ZeroInput();
        if (ended || block.timestamp > endTime) revert Sale__Closed();

        totalQuoteRaw += quoteRaw;
        account_QuoteRaw[to] += quoteRaw;

        emit Sale__Contributed(msg.sender, to, quoteRaw);
        IERC20(quote).safeTransferFrom(msg.sender, address(this), quoteRaw);
    }

    function openMarket() external nonReentrant {
        if (block.timestamp <= endTime) revert Sale__Open();
        if (ended) revert Sale__Closed();
        ended = true;

        IERC20(quote).safeApprove(token, 0);
        IERC20(quote).safeApprove(token, totalQuoteRaw);

        totalTokenAmt = IToken(token).buy(totalQuoteRaw, 0, 0, address(this), address(0));

        emit Sale__MarketOpened(totalTokenAmt, totalQuoteRaw);
        IToken(token).openMarket();
    }

    function redeem(address account) external nonReentrant {
        if (!ended) revert Sale__Open();
        uint256 quoteRaw = account_QuoteRaw[account];
        if (quoteRaw == 0) revert Sale__NothingToRedeem();

        account_QuoteRaw[account] = 0;
        uint256 tokenAmt = totalTokenAmt.mulDivDown(quoteRaw, totalQuoteRaw);

        emit Sale__Redeemed(msg.sender, account, tokenAmt);
        IERC20(token).safeTransfer(account, tokenAmt);
    }
}

contract SaleFactory {
    address public lastSale;

    event SaleFactory__Created(address indexed sale);

    function create(address token, address quote) external returns (address sale) {
        sale = address(new Sale(token, quote));
        lastSale = sale;
        emit SaleFactory__Created(sale);
    }
}
