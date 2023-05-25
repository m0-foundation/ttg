// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IList} from "src/interfaces/IList.sol";
import {IProtocolConfigurator} from "src/interfaces/IProtocolConfigurator.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SPOGGovernor} from "src/core/governor/SPOGGovernor.sol";
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
    event TaxRangeChanged(uint256 lowerRange, uint256 upperRange);
    // event NewVoteQuorumProposal(uint256 indexed proposalId);
    // event NewValueQuorumProposal(uint256 indexed proposalId);
    // event NewDoubleQuorumProposal(uint256 indexed proposalId);
    // event NewEmergencyProposal(uint256 indexed proposalId);
    event SPOGResetExecuted(address indexed newVoteToken, address indexed nnewVoteGovernor);

    // Errors
    error OnlyGovernor();
    error ZeroGovernorAddress();
    error ZeroVaultAddress();
    error ZeroCashAddress();
    error ZeroTax();
    error TaxOutOfRange();
    error ZeroInflator();
    error ZeroValueInflation();
    error ListAdminIsNotSPOG();
    error ListIsNotInMasterList();
    error EmergencyMethodNotSupported();
    error ValueTokenMistmatch();

    // Info functions about double governance and SPOG parameters
    function governor() external view returns (SPOGGovernor);
    function voteVault() external view returns (IVoteVault);
    function valueVault() external view returns (IValueVault);

    // Accepted `proposal` functions
    function addNewList(IList list) external;
    function append(address _address, IList _list) external;
    function remove(address _address, IList _list) external;
    function emergency(uint8 emergencyType, bytes calldata callData) external;
    function reset(SPOGGovernor newGovernor) external;
    function changeTax(uint256 _tax) external;
    function changeTaxRange(uint256 lowerBound, uint256 upperBound) external;

    // Token rewards functions
    function voteTokenInflationPerEpoch(uint256 epoch) external view returns (uint256);
    function valueTokenInflationPerEpoch() external view returns (uint256);
    function isGovernedMethod(bytes4 func) external view returns (bool);
    function getFee(bytes4 func) external view returns (uint256, address);

    // List accessor functions
    function isListInMasterList(address list) external view returns (bool);
}
