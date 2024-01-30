// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/dex/IRouter02.sol";
import "../interfaces/dex/IFactory02.sol";

/**
 * @title Skillon
 */
contract SkillonWPS is Context, ERC20, ERC20Burnable, Ownable {
    address constant public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD; // Dead address constant

    IRouter02 private swapRouter;
    address public liquidityPoolPair;
    mapping(address => bool) public marketPairs; // Market pairs
    mapping(address => bool) private authorizedAccounts; // Authorized account for add LP & bypass trading state
    uint8 private _decimals = 8; // Token decimals
    bool public isTradingActive = false;

    event AuthorizedAccountStateUpdated(address indexed account, bool state);
    event MarketPairUpdated(address indexed pairAddress, bool state);
    event TradingStatusUpdated(bool status);

    constructor(string memory name_, string memory symbol_, uint initialSupply_) ERC20(name_, symbol_) {
        _mint(_msgSender(), (initialSupply_ * (10 ** _decimals)));
        _createV2Pool();
    }

    /**
     * @dev Enable trading on defined market pairs
     */
    function enableTrading() public onlyOwner {
        require(!isTradingActive, "Trading already active");
        isTradingActive = true;
        emit TradingStatusUpdated(true);
    }

    /**
     * @dev Update given account as authorized or not. Authorized accounts can bypass trading enable/disable state
     * @param account Address for authorization update
     */
    function setAuthorizedAccount(address account, bool state) public onlyOwner {
        require(authorizedAccounts[account] != state, "Nothing changed");
        authorizedAccounts[account] = state;
        emit AuthorizedAccountStateUpdated(account, state);
    }

    /**
     * @dev Update a market pair's state.
     * @param pair The address of the market pair.
     * @param state The new state of the market pair.
     */
    function setMarketPair(address pair, bool state) public onlyOwner {
        require(pair != address(0), "Pair can't be address zero");
        if (marketPairs[pair] != state) {
            marketPairs[pair] = state;
            emit MarketPairUpdated(pair, state);
        }
    }

    /**
     * @dev Get current chain id
     */
    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @dev Returns the number of decimals used by the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the given transfer is authorized or not
     */
    function _isAuthorizedTransfer(address from, address to) internal view returns (bool) {
        return
        from == owner() ||
        to == owner() ||
        _msgSender() == owner() ||
        authorizedAccounts[from] ||
        authorizedAccounts[to] ||
        _isBurnTransfer(to);
    }

    /**
     * @dev Returns the transfer is burn transfer or not
     */
    function _isBurnTransfer(address to) internal pure returns (bool) {
        return
        to == DEAD_ADDRESS ||
        to == address(0);
    }

    /**
     * @dev Create V2 Pool
     */
    function _createV2Pool() internal {
        uint256 chainId = getChainID();
        if (chainId == 56) {
            // PCS
            swapRouter = IRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 1 || block.chainid == 4 || block.chainid == 3) {
            // Uni
            swapRouter = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else if (block.chainid == 43114) {
            // Joe
            swapRouter = IRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
        } else if (block.chainid == 250) {
            // Spooky
            swapRouter = IRouter02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        } else {
            revert("Chain not valid");
        }
        liquidityPoolPair = IFactory02(swapRouter.factory()).createPair(swapRouter.WETH(), address(this));
        marketPairs[liquidityPoolPair] = true;
        authorizedAccounts[_msgSender()] = true;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @param from The address from which the tokens are transferred.
     * @param to The address to which the tokens are transferred.
     * @param amount The amount of tokens transferred.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from The address from which the tokens are transferred.
     * @param to The address to which the tokens are transferred.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        _beforeTokenTransfer(from, to, amount);

        if (!_isAuthorizedTransfer(from, to)) {
            require(isTradingActive, "Trading is not enabled yet");
        }

        super._transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }
}
