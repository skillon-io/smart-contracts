// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Manager access for smart-contracts
 */
abstract contract ManagerAccess is Ownable {

    /**
     * @dev Managers mapping
     */
    mapping(address => bool) private _managers;

    event ManagerStatusUpdated(address account, bool status);

    /**
     * @dev Only owner or manager can trigger this functions
     */
    modifier onlyOwnerOrManager() {
        require(owner() == _msgSender() || _managers[_msgSender()], "Only owner or manager");
        _;
    }

    constructor(){

    }

    /**
     * @dev Returns given account is manager
     */
    function isManager(address account) public view returns (bool) {
        return _managers[account];
    }

    /**
     * @dev Set given account manager status
     */
    function setManagerStatus(address account, bool status) public onlyOwner {
        require(_managers[account] != status, "Manager: Status not updated");
        _managers[account] = status;

        emit ManagerStatusUpdated(account, status);
    }
}
