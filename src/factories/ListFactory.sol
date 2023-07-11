// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { List } from "../periphery/List.sol";

/// @title ListFactory
/// @notice This contract is used to deploy List contracts
contract ListFactory {
    event ListDeployed(address indexed addr, uint256 salt);

    /// @notice Create a new List
    /// @dev creates a list with the given name, adds the addresses to it, and sets admin
    function deploy(
        address spog,
        string memory name,
        address[] memory addresses,
        uint256 salt
    ) public returns (address) {
        List list = new List{ salt: bytes32(salt) }(name);

        for (uint256 i; i < addresses.length; ++i) {
            list.add(addresses[i]);
        }

        list.changeAdmin(spog);

        emit ListDeployed(address(list), salt);

        return address(list);
    }

    /// @notice This function is used to get the bytecode of the SPOG contract to be deployed
    function getBytecode(string memory name) public pure returns (bytes memory) {
        bytes memory bytecode = type(List).creationCode;

        return abi.encodePacked(bytecode, abi.encode(name));
    }

    /// @notice Compute the address of the List contract to be deployed
    /// @param bytecode The bytecode of the contract to be deployed
    /// @param salt is a random number used to create an address
    function predictListAddress(bytes memory bytecode, uint256 salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }
}
