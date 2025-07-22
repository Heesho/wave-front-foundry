// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IWaveFront {
    function quote() external view returns (address);

    function create(string calldata name, string calldata symbol, string calldata uri)
        external
        returns (address token);
}

interface IToken {
    function content() external view returns (address);

    function sale() external view returns (address);

    function rewarder() external view returns (address);

    function buy(
        uint256 amountQuoteIn,
        uint256 minAmountTokenOut,
        uint256 expireTimestamp,
        address to,
        address provider
    ) external returns (uint256 amountTokenOut);

    function sell(
        uint256 amountTokenIn,
        uint256 minAmountQuoteOut,
        uint256 expireTimestamp,
        address to,
        address provider
    ) external returns (uint256 amountQuoteOut);
}

interface ISale {
    function contribute(address account, uint256 amount) external;

    function redeem(address account) external;

    function openMarket() external;

    function ended() external view returns (bool);

    function endTime() external view returns (uint256);

    function token() external view returns (address);
}

interface IContent {
    function getNextPrice(uint256 tokenId) external view returns (uint256);

    function create(address account, string memory _uri) external returns (uint256);

    function curate(address account, uint256 tokenId) external;

    function distribute() external;
}

interface IRewarder {
    function getReward(address account) external;

    function notifyRewardAmount(address token, uint256 amount) external;
}

contract WaveFrontRouter is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    address public immutable wavefront;

    mapping(address => address) public account_Affiliate;

    event WaveFrontRouter__TokenCreated(
        string name, string symbol, string uri, address indexed token, address indexed creator
    );
    event WaveFrontRouter__Buy(
        address indexed token,
        address indexed account,
        address indexed affiliate,
        uint256 amountQuoteIn,
        uint256 amountTokenOut
    );
    event WaveFrontRouter__Sell(
        address indexed token,
        address indexed account,
        address indexed affiliate,
        uint256 amountTokenIn,
        uint256 amountQuoteOut
    );
    event WaveFrontRouter__Contribute(
        address indexed token, address quote, address indexed account, uint256 amountQuote
    );
    event WaveFrontRouter__Redeem(address indexed token, address indexed account);
    event WaveFrontRouter__ContentCreated(
        address indexed token, address indexed content, address indexed account, uint256 tokenId
    );
    event WaveFrontRouter__ContentCurated(
        address indexed token, address indexed content, address indexed account, uint256 price, uint256 tokenId
    );
    event WaveFrontRouter__AffiliateSet(address indexed account, address indexed affiliate);
    event WaveFrontRouter__MarketOpened(address indexed token, address indexed sale);

    constructor(address _wavefront) {
        wavefront = _wavefront;
    }

    function createToken(string calldata name, string calldata symbol, string calldata uri)
        external
        nonReentrant
        returns (address token)
    {
        token = IWaveFront(wavefront).create(name, symbol, uri);
        emit WaveFrontRouter__TokenCreated(name, symbol, uri, token, msg.sender);
    }

    function buy(
        address token,
        address affiliate,
        uint256 amountQuoteIn,
        uint256 minAmountTokenOut,
        uint256 expireTimestamp
    ) external nonReentrant {
        _setAffiliate(affiliate);

        address quote = IWaveFront(wavefront).quote();
        IERC20(quote).safeTransferFrom(msg.sender, address(this), amountQuoteIn);
        _safeApprove(quote, token, amountQuoteIn);

        uint256 amountTokenOut = IToken(token).buy(
            amountQuoteIn, minAmountTokenOut, expireTimestamp, msg.sender, account_Affiliate[msg.sender]
        );

        uint256 remainingQuote = IERC20(quote).balanceOf(address(this));
        if (remainingQuote > 0) {
            IERC20(quote).safeTransfer(msg.sender, remainingQuote);
        }

        _distributeFees(token);

        emit WaveFrontRouter__Buy(token, msg.sender, affiliate, amountQuoteIn, amountTokenOut);
    }

    function sell(
        address token,
        address affiliate,
        uint256 amountTokenIn,
        uint256 minAmountQuoteOut,
        uint256 expireTimestamp
    ) external nonReentrant {
        _setAffiliate(affiliate);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountTokenIn);
        uint256 amountQuoteOut = IToken(token).sell(
            amountTokenIn, minAmountQuoteOut, expireTimestamp, msg.sender, account_Affiliate[msg.sender]
        );

        _distributeFees(token);

        emit WaveFrontRouter__Sell(token, msg.sender, affiliate, amountTokenIn, amountQuoteOut);
    }

    function contribute(address token, uint256 amountQuoteIn) external nonReentrant {
        address sale = IToken(token).sale();

        address quote = IWaveFront(wavefront).quote();
        IERC20(quote).safeTransferFrom(msg.sender, address(this), amountQuoteIn);
        _safeApprove(quote, sale, amountQuoteIn);

        ISale(sale).contribute(msg.sender, amountQuoteIn);

        uint256 remainingQuote = IERC20(quote).balanceOf(address(this));
        if (remainingQuote > 0) {
            IERC20(quote).safeTransfer(msg.sender, remainingQuote);
        }

        emit WaveFrontRouter__Contribute(token, quote, msg.sender, amountQuoteIn);
        _checkAndOpenMarket(sale);
    }

    function redeem(address token) external nonReentrant {
        address sale = IToken(token).sale();
        _checkAndOpenMarket(sale);

        ISale(sale).redeem(msg.sender);

        emit WaveFrontRouter__Redeem(token, msg.sender);
    }

    function createContent(address token, string calldata uri) external nonReentrant {
        address content = IToken(token).content();
        uint256 tokenId = IContent(content).create(msg.sender, uri);

        emit WaveFrontRouter__ContentCreated(token, content, msg.sender, tokenId);
    }

    function curateContent(address token, uint256 tokenId) external nonReentrant {
        address content = IToken(token).content();
        address quote = IWaveFront(wavefront).quote();
        uint256 price = IContent(content).getNextPrice(tokenId);

        IERC20(quote).safeTransferFrom(msg.sender, address(this), price);
        _safeApprove(quote, content, price);

        IContent(content).curate(msg.sender, tokenId);

        emit WaveFrontRouter__ContentCurated(token, content, msg.sender, price, tokenId);
    }

    function getContentReward(address token) external {
        address rewarder = IToken(token).rewarder();
        IRewarder(rewarder).getReward(msg.sender);
    }

    function notifyContentRewardAmount(address token, address rewardToken, uint256 amount) external {
        address rewarder = IToken(token).rewarder();
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
        _safeApprove(rewardToken, rewarder, amount);
        IRewarder(rewarder).notifyRewardAmount(rewardToken, amount);
    }

    function _setAffiliate(address affiliate) internal {
        if (account_Affiliate[msg.sender] == address(0) && affiliate != address(0)) {
            account_Affiliate[msg.sender] = affiliate;
            emit WaveFrontRouter__AffiliateSet(msg.sender, affiliate);
        }
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        IERC20(token).safeApprove(spender, 0);
        IERC20(token).safeApprove(spender, amount);
    }

    function _checkAndOpenMarket(address sale) internal {
        if (block.timestamp > ISale(sale).endTime() && !ISale(sale).ended()) {
            ISale(sale).openMarket();
            emit WaveFrontRouter__MarketOpened(ISale(sale).token(), sale);
        }
    }

    function _distributeFees(address token) internal {
        address content = IToken(token).content();
        IContent(content).distribute();
    }

    function withdrawStuckTokens(address _token, address _to) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_to, balance);
    }
}
