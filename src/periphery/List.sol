// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IList } from "../interfaces/periphery/IList.sol";

import { ERC165CheckerSPOG } from "./ERC165CheckerSPOG.sol";

/// @notice List contract where only an admin (SPOG) can add and remove addresses from a list
contract List is ERC165CheckerSPOG, IList {
    // address list
    mapping(address address_ => bool isInList) internal _list;

    address private _admin;
    string private _name;

    // constructor sets the admin address
    constructor(string memory name_) {
        _name = name_;
        _admin = msg.sender;
    }

    /// @notice Returns the admin address
    function admin() public view returns (address) {
        return _admin;
    }

    /// @notice Returns the name of the list
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Add an address to the list
    /// @param address_ The address to add
    function add(address address_) external {
        if (msg.sender != _admin) revert NotAdmin();

        // require that the address is not already on the list
        if (this.contains(address_)) revert AddressIsAlreadyInList();

        // add the address to the list
        _list[address_] = true;
        emit AddressAdded(address_);
    }

    /// @notice Remove an address from the list
    /// @param address_ The address to remove
    function remove(address address_) external {
        if (msg.sender != _admin) revert NotAdmin();

        // require that the address is on the list
        if (!this.contains(address_)) revert AddressIsNotInList();

        // remove the address from the list
        _list[address_] = false;
        emit AddressRemoved(address_);
    }

    /// @notice Check if an address is on the list
    /// @param address_ The address to check
    function contains(address address_) external view returns (bool) {
        return _list[address_];
    }

    /// @notice Change the admin address
    /// @param newAdmin_ The new admin address
    function changeAdmin(address newAdmin_) external onlySPOGInterface(newAdmin_) {
        if (msg.sender != _admin) revert NotAdmin();

        _admin = newAdmin_;
        emit AdminChanged(newAdmin_);
    }
}
