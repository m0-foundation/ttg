// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IList} from "src/interfaces/IList.sol";
import {IProtocolConfigurator} from "src/interfaces/IProtocolConfigurator.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

interface ISPOG is IProtocolConfigurator, IERC165 {
    enum EmergencyType {
        Remove,
        Append,
        ChangeConfig
    }

    // Events
    event NewListAdded(address indexed _list);
    event AddressAppendedToList(address indexed _list, address indexed _address);
    event AddressRemovedFromList(address indexed _list, address indexed _address);
    event EmergencyExecuted(uint8 emergencyType, bytes callData);
    event TaxChanged(uint256 indexed tax);
    event NewVoteQuorumProposal(uint256 indexed proposalId);
    event NewValueQuorumProposal(uint256 indexed proposalId);
    event NewDoubleQuorumProposal(uint256 indexed proposalId);
    event NewEmergencyProposal(uint256 indexed proposalId);
    event DoubleQuorumFinalized(bytes32 indexed identifier);
    event SPOGResetExecuted(address indexed newVoteToken, address indexed nnewVoteGovernor);

    // Errors
    error EmergencyMethodNotSupported();
    error InvalidParameter(bytes32 what);
    error ListAdminIsNotSPOG();
    error ListIsNotInMasterList();
    error ListIsAlreadyInMasterList();
    error InvalidProposal();
    error NotGovernedMethod(bytes4 funcSelector);
    error ValueVoteProposalIdsMistmatch(uint256 voteProposalId, uint256 valueProposalId);
    error ValueGovernorDidNotApprove(uint256 proposalId);
    error ValueTokenMistmatch();
    error GovernorsShouldNotBeSame();
    error VaultAddressCannotBeZero();
    error ZeroAddress();
    error ZeroValues();
    error InitTaxOutOfRange();
    error InitCashAndInflatorCannotBeZero();
    error TaxOutOfRange();
    error OnlyValueGovernor();
    error OnlyVoteGovernor();

    // Info functions about double governance and SPOG parameters
    function valueGovernor() external view returns (SPOGGovernorBase);
    function voteGovernor() external view returns (SPOGGovernorBase);
    function valueVault() external view returns (IValueVault);
    function voteVault() external view returns (IVoteVault);
    function taxRange() external view returns (uint256, uint256);

    // Accepted `proposal` functions
    function addNewList(IList list) external;
    function append(address _address, IList _list) external;
    function remove(address _address, IList _list) external;
    function emergency(uint8 emergencyType, bytes calldata callData) external;
    function reset(SPOGGovernorBase newVoteGovernor) external;
    function change(bytes32 what, bytes calldata value) external;
    function changeTax(uint256 _tax) external;

    // Token rewards functions
    function voteTokenInflationPerEpoch() external view returns (uint256);
    function valueTokenInflationPerEpoch() external view returns (uint256);

    // Governance process functions
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    // List accessor functions
    function isListInMasterList(address list) external view returns (bool);
}
