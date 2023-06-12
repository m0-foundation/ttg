// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IList} from "src/interfaces/IList.sol";
import {List} from "src/periphery/List.sol";

/// @title ListFactory
/// @notice This contract is used to deploy List contracts
contract ListFactory {
    event ListDeployed(address indexed addr, uint256 salt);

    /// @notice Create a new List
    /// @dev creates a list with the given name, adds the addresses to it, and sets admin
    function deploy(address _spog, string memory _name, address[] memory addresses, uint256 _salt)
        public
        returns (IList)
    {
        IList list = IList(address(new List{salt: bytes32(_salt)}(_name)));

        uint256 i;
        for (i; i < addresses.length;) {
            list.add(addresses[i]);
            unchecked {
                ++i;
            }
        }

        list.changeAdmin(_spog);

        emit ListDeployed(address(list), _salt);

        return list;
    }

    /// @notice This function is used to get the bytecode of the SPOG contract to be deployed
    function getBytecode(string memory _name) public pure returns (bytes memory) {
        bytes memory bytecode = type(List).creationCode;

        return abi.encodePacked(bytecode, abi.encode(_name));
    }

    /// @notice Compute the address of the List contract to be deployed
    /// @param bytecode The bytecode of the contract to be deployed
    /// @param _salt is a random number used to create an address
    function predictListAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    fallback() external {
        revert("ListFactory: non-existent function");
    }
}
