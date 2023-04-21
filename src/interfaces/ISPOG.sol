// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "src/interfaces/IList.sol";

interface ISPOG {
    // Events
    event NewListAdded(address indexed _list);
    event ListRemoved(address indexed _list);
    event AddressAppendedToList(address indexed _list, address indexed _address);
    event AddressRemovedFromList(address indexed _list, address indexed _address);
    event EmergencyAddressRemovedFromList(address indexed _list, address indexed _address);
    event TaxChanged(uint256 indexed tax);
    event NewVoteQuorumProposal(uint256 indexed proposalId);
    event NewValueQuorumProposal(uint256 indexed proposalId);
    event NewDoubleQuorumProposal(uint256 indexed proposalId);
    event NewEmergencyProposal(uint256 indexed proposalId);
    event DoubleQuorumFinalized(bytes32 indexed identifier);
    event SPOGResetExecuted(address indexed newVoteToken, address indexed nnewVoteGovernor);

    // Errors
    error InvalidParameter(bytes32 what);
    error ListAdminIsNotSPOG();
    error ListIsNotInMasterList();
    error ListIsAlreadyInMasterList();
    error AddressIsAlreadyInList();
    error AddressIsNotInList();
    error InvalidProposal();
    error NotGovernedMethod(bytes4 funcSelector);
    error ValueVoteProposalIdsMistmatch(uint256 voteProposalId, uint256 valueProposalId);
    error ValueGovernorDidNotApprove(uint256 proposalId);
    error ValueTokenMistmatch();

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
