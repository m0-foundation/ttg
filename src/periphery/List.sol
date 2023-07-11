// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IList } from "../interfaces/periphery/IList.sol";

import { ERC165CheckerSPOG } from "./ERC165CheckerSPOG.sol";

/// @notice List contract where only an admin (SPOG) can add and remove addresses from a list
contract List is ERC165CheckerSPOG, IList {

    // address list
    mapping(address => bool) internal list;

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
    /// @param _address The address to add
    function add(address _address) external {
        if (msg.sender != _admin) revert NotAdmin();

        // require that the address is not already on the list
        if (this.contains(_address)) {
            revert AddressIsAlreadyInList();
        }

        // add the address to the list
        list[_address] = true;
        emit AddressAdded(_address);
    }

    /// @notice Remove an address from the list
    /// @param _address The address to remove
    function remove(address _address) external {
        if (msg.sender != _admin) revert NotAdmin();

        // require that the address is on the list
        if (!this.contains(_address)) {
            revert AddressIsNotInList();
        }

        // remove the address from the list
        list[_address] = false;
        emit AddressRemoved(_address);
    }

    /// @notice Check if an address is on the list
    /// @param _address The address to check
    function contains(address _address) external view returns (bool) {
        return list[_address];
    }

    /// @notice Change the admin address
    /// @param _newAdmin The new admin address
    function changeAdmin(address _newAdmin) external onlySPOGInterface(_newAdmin) {
        if (msg.sender != _admin) revert NotAdmin();

        _admin = _newAdmin;
        emit AdminChanged(_newAdmin);
    }

}
