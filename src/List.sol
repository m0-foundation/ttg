// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

error NotAdmin();

/// @notice List contract where only an admin (SPOG) can add and remove addresses from a list
// TODO: add Support Interfaace so the admin is an SPOG
contract List {
    // address list
    mapping(address => bool) internal list;

    // create an admin address
    address public admin;

    event AddressAdded(address _address);
    event AddressRemoved(address _address);

    // constructor sets the admin address
    constructor() {
        admin = msg.sender;
    }

    /// @notice Add an address to the list
    /// @param _address The address to add
    function add(address _address) external {
        if (msg.sender != admin) revert NotAdmin();

        // add the address to the list
        list[_address] = true;
        emit AddressAdded(_address);
    }

    /// @notice Remove an address from the list
    /// @param _address The address to remove
    function remove(address _address) external {
        if (msg.sender != admin) revert NotAdmin();

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
    function changeAdmin(address _newAdmin) external {
        if (msg.sender != admin) revert NotAdmin();

        admin = _newAdmin;
    }
}
