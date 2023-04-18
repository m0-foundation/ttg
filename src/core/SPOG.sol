// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {SPOGStorage, ISPOGGovernor, IERC20, ISPOG} from "src/core/SPOGStorage.sol";
import {IList} from "src/interfaces/IList.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/// @title SPOG
/// @dev Contracts for governing lists and managing communal property through token voting.
/// @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
/// @notice A SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A SPOG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.
contract SPOG is SPOGStorage, ERC165 {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    address public immutable vault;

    // List of methods that can be executed by SPOG governance
    mapping(bytes4 => bool) public governedMethods;

    uint256 private constant inMasterList = 1;
    uint256 public constant EMERGENCY_REMOVE_TAX_MULTIPLIER = 12;

    // List of addresses that are part of the masterlist
    // Masterlist declaration. address => uint256. 0 = not in masterlist, 1 = in masterlist
    EnumerableMap.AddressToUintMap private masterlist;

    /// @notice Create a new SPOG
    /// @param _initSPOGData The data used to initialize spogData
    /// @param _vault The address of the `Vault` contract
    /// @param _voteTime The duration of a voting epoch in blocks
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _valueFixedInflationAmount The fixed inflation amount for the $VALUE token
    /// @param _voteGovernor The address of the `SPOGGovernor` which $VOTE token is used for voting
    /// @param _valueGovernor The address of the `SPOGGovernor` which $VALUE token is used for voting
    constructor(
        bytes memory _initSPOGData,
        address _vault,
        uint256 _voteTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _valueFixedInflationAmount,
        ISPOGGovernor _voteGovernor,
        ISPOGGovernor _valueGovernor
    ) SPOGStorage(_voteGovernor, _valueGovernor, _voteTime, _voteQuorum, _valueQuorum, _valueFixedInflationAmount) {
        // TODO: add require statements for variables
        vault = _vault;

        initSPOGData(_initSPOGData);
        initGovernedMethods();
    }

    /// @dev Getter for finding whether a list is in a masterlist
    /// @return Whether the list is in the masterlist
    function isListInMasterList(address list) external view returns (bool) {
        return masterlist.contains(list);
    }

    // ********** CRUD Masterlist FUNCTIONS ********** //
    // functions for adding lists to masterlist and appending/removing addresses to/from lists through VOTE

    /// @notice Add a new list to the master list of the SPOG
    /// @param list The list address of the list to be added
    function addNewList(IList list) external onlyVoteGovernor {
        if (list.admin() != address(this)) {
            revert ListAdminIsNotSPOG();
        }
        // add the list to the master list
        masterlist.set(address(list), inMasterList);
        emit NewListAdded(address(list));
    }

    /// @notice Remove a list from the master list of the SPOG
    /// @param list  The list address of the list to be removed
    function removeList(IList list) external onlyVoteGovernor {
        // require that the list is on the master list
        if (!masterlist.contains(address(list))) {
            revert ListIsNotInMasterList();
        }

        // remove the list from the master list
        masterlist.remove(address(list));
        emit ListRemoved(address(list));
    }

    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external onlyVoteGovernor {
        // require that the list is on the master list
        if (!masterlist.contains(address(_list))) {
            revert ListIsNotInMasterList();
        }

        // require that the address is not already on the list
        if (_list.contains(_address)) {
            revert AddressIsAlreadyInList();
        }

        // append the address to the list
        _list.add(_address);
        emit AddressAppendedToList(address(_list), _address);
    }

    // create function to remove an address from a list
    /// @notice Remove an address from a list
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    function remove(address _address, IList _list) external onlyVoteGovernor {
        _removeFromList(_address, _list);
        emit AddressRemovedFromList(address(_list), _address);
    }

    // create function to remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @notice Remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    // TODO: IMPORTANT: right now voting period and logic is the same as for otherfunctions
    // TODO: IMPORTANT: implement immediate remove
    function emergencyRemove(address _address, IList _list) external onlyVoteGovernor {
        _removeFromList(_address, _list);
        emit EmergencyAddressRemovedFromList(address(_list), _address);
    }

    // ********** SPOG Governance interface FUNCTIONS ********** //
    // functions for the Governance proposal lifecycle including propose, execute and potentially batch vote

    /// @notice Create a new proposal.
    // Similar function sig to propose in Governor.sol so that it is compatible with tools such as Snapshot and Tally
    /// @dev Calls `propose` function of the vote or value and vote governors (double quorum)
    /// @param targets The targets of the proposal
    /// @param values The values of the proposal
    /// @param calldatas The calldatas of the proposal
    /// @param description The description of the proposal
    /// @return proposalId The ID of the proposal
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external override returns (uint256) {
        // allow only 1 SPOG change with no value per proposal
        if (targets.length != 1 || targets[0] != address(this) || values[0] != 0) {
            revert InvalidProposal();
        }

        return propose(calldatas[0], description);
    }

    /// @notice Create a new proposal
    /// @dev Calls `propose` function of the vote or value and vote governors (double quorum)
    /// @param callData The calldata of the proposal
    /// @param description The description of the proposal
    /// @return proposalId The ID of the proposal
    function propose(bytes memory callData, string memory description) public override returns (uint256) {
        bytes4 executableFuncSelector = bytes4(callData);
        if (!governedMethods[executableFuncSelector]) {
            revert NotGovernedMethod(executableFuncSelector);
        }

        address[] memory targets = new address[](1);
        targets[0] = address(this);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        // For all the operations pay flat fee, except for emergency remove pay 12 * fee
        uint256 fee = executableFuncSelector == this.emergencyRemove.selector
            ? EMERGENCY_REMOVE_TAX_MULTIPLIER * spogData.tax
            : spogData.tax;
        _pay(fee);

        // handle any value quorum proposals first
        if (executableFuncSelector == this.sellERC20.selector) {
          bytes memory params = _removeSelector(callData);
          (address sellToken, uint256 amount) = abi.decode(params, (address, uint256));

          if(address(0) == sellToken) revert InvalidProposal();
          if(amount == 0) revert InvalidProposal();
 
          // disallow proposing selling cash for cash
          if(sellToken == address(spogData.cash)) revert InvalidProposal();

          // disallow proposing selling voting token. Does not require voting
          if(sellToken == address(voteGovernor.votingToken())) revert InvalidProposal();

          if(IERC20(sellToken).balanceOf(vault) < amount) revert InvalidProposal();

          uint256 valueProposalId = valueGovernor.propose(targets, values, calldatas, description);

          emit NewValueQuorumProposal(valueProposalId);

          return valueProposalId;
        }

        // Create proposal in vote governor
        uint256 proposalId = voteGovernor.propose(targets, values, calldatas, description);
        // Register emergency proposal with vote governor
        if (executableFuncSelector == this.emergencyRemove.selector) {
            voteGovernor.registerEmergencyProposal(proposalId);

            emit NewEmergencyProposal(proposalId);
        }
        // If we request to change config parameter, value governance should vote too
        else if (executableFuncSelector == this.change.selector) {
            uint256 valueProposalId = valueGovernor.propose(targets, values, calldatas, description);

            // proposal ids should match
            if (valueProposalId != proposalId) {
                revert ValueVoteProposalIdsMistmatch(proposalId, valueProposalId);
            }

            emit NewDoubleQuorumProposal(proposalId);
        } else {
            emit NewVoteQuorumProposal(proposalId);
        }

        return proposalId;
    }

    /// @notice Execute a proposal
    /// @dev Calls `execute` function of the vote governors, possibly checking value governor quorum (double quorum)
    /// @param targets The targets of the proposal
    /// @param values The values of the proposal
    /// @param calldatas The calldatas of the proposal
    /// @param descriptionHash The description hash of the proposal
    /// @return proposalId The ID of the proposal
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external override returns (uint256) {
        bytes4 executableFuncSelector = bytes4(calldatas[0]);
        uint256 proposalId = voteGovernor.hashProposal(targets, values, calldatas, descriptionHash);

        // Check that both value and vote governance approved parameter change
        if (executableFuncSelector == this.change.selector) {
            if (valueGovernor.state(proposalId) != ISPOGGovernor.ProposalState.Succeeded) {
                revert ValueGovernorDidNotApprove(proposalId);
            }
        }

        if (executableFuncSelector == this.sellERC20.selector) {
            valueGovernor.execute(targets, values, calldatas, descriptionHash);
        } else {
            voteGovernor.execute(targets, values, calldatas, descriptionHash);
        }

        return proposalId;

    }

    /// @notice Sell an asset in the vault
    /// @dev Calls `sell` function of the vault
    /// @param token The token to sell
    /// @param amount The amount of the token to sell
    function sellERC20(address token, uint256 amount) external onlyValueGovernor {
        IVault(vault).sellERC20(token, address(spogData.cash), spogData.sellTime, amount);
    }

    // ********** Utility FUNCTIONS ********** //
    function tokenInflationCalculation() public view returns (uint256) {
        if (msg.sender == address(voteGovernor)) {
            uint256 votingTokenTotalSupply = IERC20(voteGovernor.votingToken()).totalSupply();
            uint256 inflator = spogData.inflator;

            return (votingTokenTotalSupply * inflator) / 100;
        } else if (msg.sender == address(valueGovernor)) {
            return valueFixedInflationAmount;
        }

        return 0;
    }

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }

    // ********** Private FUNCTIONS ********** //

    function initGovernedMethods() private {
        // TODO: review if there is better, more efficient way to do it
        governedMethods[this.append.selector] = true;
        governedMethods[this.changeTax.selector] = true;
        governedMethods[this.remove.selector] = true;
        governedMethods[this.removeList.selector] = true;
        governedMethods[this.addNewList.selector] = true;
        governedMethods[this.change.selector] = true;
        governedMethods[this.emergencyRemove.selector] = true;
        governedMethods[this.sellERC20.selector] = true;
    }

    /// @notice pay tax from the caller to the SPOG
    /// @param _amount The amount to be transferred
    function _pay(uint256 _amount) private {
        // transfer the amount from the caller to the SPOG
        spogData.cash.safeTransferFrom(msg.sender, address(vault), _amount);
    }

    function _removeFromList(address _address, IList _list) private {
        // require that the list is on the master list
        if (!masterlist.contains(address(_list))) {
            revert ListIsNotInMasterList();
        }

        // require that the address is on the list
        if (!_list.contains(_address)) {
            revert AddressIsNotInList();
        }

        // remove the address from the list
        _list.remove(_address);
    }

    function _removeSelector(bytes memory callData) internal pure returns (bytes memory) {
        uint256 length = callData.length - 4;
        bytes memory params = new bytes(length);

        uint256 i;
        for (i; i < length;) {
            params[i] = callData[i + 4];
            unchecked { ++i; }
        }

        return params;
    }

    fallback() external {
        revert("SPOG: non-existent function");
    }
}
