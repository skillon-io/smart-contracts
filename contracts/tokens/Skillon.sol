// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/dex/IRouter02.sol";
import "../interfaces/dex/IFactory02.sol";

/**
 * @title Skillon
 * @dev A contract representing the Skillon token with fee functionalities.
 */
contract Skillon is Context, ERC20, ERC20Burnable, Ownable {

    uint8 private _decimals = 8; // Token decimals

    constructor(string memory name_, string memory symbol_, uint initialSupply_) ERC20(name_, symbol_) {
        _mint(_msgSender(), (initialSupply_ * (10 ** _decimals)));
    }

    /**
     * @dev Returns the number of decimals used by the token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
