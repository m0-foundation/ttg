// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "src/interfaces/IList.sol";

interface ISPOG {
    // Events
    event NewListAdded(address _list);
    event ListRemoved(address _list);
    event AddressAppendedToList(address _list, address _address);
    event AddressRemovedFromList(address _list, address _address);
    event EmergencyAddressRemovedFromList(address _list, address _address);
    event TaxChanged(uint256 indexed tax);
    event NewProposal(uint256 indexed proposalId);
    event NewDoubleQuorumProposal(uint256 indexed proposalId);
    event NewEmergencyProposal(uint256 indexed proposalId);
    event DoubleQuorumFinalized(bytes32 indexed identifier);

    // Errors
    error InvalidParameter(bytes32 what);

    // Logic functions
    function vault() external view returns (address);

    function addNewList(IList list) external;

    function removeList(IList list) external;

    function append(address _address, IList _list) external;

    function remove(address _address, IList _list) external;

    function emergencyRemove(address _address, IList _list) external;

    // Utility functions
    function tokenInflationCalculation() external view returns (uint256);

    // Governance process functions
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function propose(bytes memory callData, string memory description) external returns (uint256);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);
}
