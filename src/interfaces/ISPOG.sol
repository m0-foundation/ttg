// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "src/interfaces/IList.sol";

interface ISPOG {
    // Events
    event NewListAdded(address _list);
    event ListRemoved(address _list);
    event AddressAppendedToList(address _list, address _address);
    event AddressRemovedFromList(address _list, address _address);
    event NewProposal(uint256 indexed proposalId);
    event TaxChanged(uint256 indexed tax);
    event DoubleQuorumInitiated(bytes32 indexed identifier);
    event DoubleQuorumFinalized(bytes32 indexed identifier);
    error InvalidParameter(bytes32 what);

    // functions
    function vault() external view returns (address);

    function addNewList(IList list) external;

    function removeList(IList list) external;

    function append(address _address, IList _list) external;

    function remove(address _address, IList _list) external;

    function emergencyRemove(address _address, IList _list) external;

    function tokenInflationCalculation() external view returns (uint256);
}
