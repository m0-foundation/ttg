// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IList {

    // events
    event AddressAdded(address indexed _address);
    event AddressRemoved(address indexed _address);
    event AdminChanged(address indexed _newAdmin);

    // errors
    error AddressIsAlreadyInList();
    error AddressIsNotInList();
    error NotAdmin();

    function admin() external view returns (address);
    function name() external view returns (string memory);
    function add(address _address) external;
    function remove(address _address) external;
    function contains(address _address) external view returns (bool);
    function changeAdmin(address _newAdmin) external;

}
