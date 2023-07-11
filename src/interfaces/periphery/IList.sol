// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IList {
    // events
    event AddressAdded(address indexed address_);
    event AddressRemoved(address indexed address_);
    event AdminChanged(address indexed newAdmin);

    // errors
    error AddressIsAlreadyInList();
    error AddressIsNotInList();
    error NotAdmin();

    function admin() external view returns (address);

    function name() external view returns (string memory);

    function add(address address_) external;

    function remove(address address_) external;

    function contains(address address_) external view returns (bool);

    function changeAdmin(address newAdmin_) external;
}
