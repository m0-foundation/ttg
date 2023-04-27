// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IList {
    function admin() external view returns (address);

    function name() external view returns (string memory);

    function add(address _address) external;

    function remove(address _address) external;

    function contains(address _address) external view returns (bool);

    function changeAdmin(address _newAdmin) external;
}
