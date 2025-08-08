// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ITokenFactory {
    function create(
        string memory name,
        string memory symbol,
        string memory coverUri,
        address wavefront,
        address quote,
        uint256 initialSupply,
        uint256 reserveVirtQuoteRaw,
        address saleFactory,
        address contentFactory,
        address rewarderFactory,
        address owner,
        bool isPrivate
    ) external returns (address token);
}

interface IToken {
    function sale() external view returns (address);

    function content() external view returns (address);

    function rewarder() external view returns (address);
}

contract WaveFront is Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant RESERVE_VIRT_QUOTE_RAW = 100_000 * 1e6;

    address public immutable quote;

    address public tokenFactory;
    address public saleFactory;
    address public contentFactory;
    address public rewarderFactory;
    address public treasury;

    uint256 public index;
    mapping(uint256 => address) public index_Token;
    mapping(address => uint256) public token_Index;

    event WaveFront__TokenCreated(
        string name,
        string symbol,
        string uri,
        uint256 index,
        address token,
        address sale,
        address content,
        address rewarder,
        address indexed owner,
        bool isPrivate
    );
    event WaveFront__TreasurySet(address newTreasury);
    event WaveFront__TokenFactorySet(address newTokenFactory);
    event WaveFront__SaleFactorySet(address newSaleFactory);
    event WaveFront__ContentFactorySet(address newContentFactory);
    event WaveFront__RewarderFactorySet(address newRewarderFactory);

    constructor(
        address _quote,
        address _tokenFactory,
        address _saleFactory,
        address _contentFactory,
        address _rewarderFactory
    ) Ownable() {
        quote = _quote;
        tokenFactory = _tokenFactory;
        saleFactory = _saleFactory;
        contentFactory = _contentFactory;
        rewarderFactory = _rewarderFactory;
    }

    function create(string memory name, string memory symbol, string memory uri, address owner, bool isPrivate)
        external
        returns (address token)
    {
        index++;

        token = ITokenFactory(tokenFactory).create(
            name,
            symbol,
            uri,
            address(this),
            quote,
            INITIAL_SUPPLY,
            RESERVE_VIRT_QUOTE_RAW,
            saleFactory,
            contentFactory,
            rewarderFactory,
            owner,
            isPrivate
        );

        index_Token[index] = token;
        token_Index[token] = index;

        emit WaveFront__TokenCreated(
            name,
            symbol,
            uri,
            index,
            token,
            IToken(token).sale(),
            IToken(token).content(),
            IToken(token).rewarder(),
            owner,
            isPrivate
        );
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit WaveFront__TreasurySet(_treasury);
    }

    function setTokenFactory(address _tokenFactory) external onlyOwner {
        tokenFactory = _tokenFactory;
        emit WaveFront__TokenFactorySet(_tokenFactory);
    }

    function setSaleFactory(address _saleFactory) external onlyOwner {
        saleFactory = _saleFactory;
        emit WaveFront__SaleFactorySet(_saleFactory);
    }

    function setContentFactory(address _contentFactory) external onlyOwner {
        contentFactory = _contentFactory;
        emit WaveFront__ContentFactorySet(_contentFactory);
    }

    function setRewarderFactory(address _rewarderFactory) external onlyOwner {
        rewarderFactory = _rewarderFactory;
        emit WaveFront__RewarderFactorySet(_rewarderFactory);
    }
}
