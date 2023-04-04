// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {SPOGStorage, ISPOGGovernor, IERC20, ISPOG} from "src/core/SPOGStorage.sol";
import {IList} from "src/interfaces/IList.sol";
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
    /// @param _voteGovernor The address of the `SPOGGovernor` which $VOTE token is used for voting
    /// @param _valueGovernor The address of the `SPOGGovernor` which $VALUE token is used for voting
    constructor(
        bytes memory _initSPOGData,
        address _vault,
        uint256 _voteTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        ISPOGGovernor _voteGovernor,
        ISPOGGovernor _valueGovernor
    ) SPOGStorage(_voteGovernor, _valueGovernor, _voteTime, _voteQuorum, _valueQuorum) {
        // TODO: add require statements for variables
        vault = _vault;

        initSPOGData(_initSPOGData);
    }

    /// @param _initSPOGData The data used to initialize spogData
    function initSPOGData(bytes memory _initSPOGData) internal {
        // _cash The currency accepted for tax payment in the SPOG (must be ERC20)
        // _taxRange The minimum and maximum value of `tax`
        // _inflator The percentage supply increase in $VOTE for each voting epoch
        // _reward The number of $VALUE to be distributed in each voting epoch
        // _inflatorTime The duration of an auction if $VOTE is inflated (should be less than `VOTE TIME`)
        // _sellTime The duration of an auction if `SELL` is called
        // _tax The cost (in `cash`) to call various functions
        (
            address _cash,
            uint256[2] memory _taxRange,
            uint256 _inflator,
            uint256 _reward,
            uint256 _inflatorTime,
            uint256 _sellTime,
            uint256 _forkTime,
            uint256 _tax
        ) = abi.decode(_initSPOGData, (address, uint256[2], uint256, uint256, uint256, uint256, uint256, uint256));

        spogData = SPOGData({
            cash: IERC20(_cash),
            taxRange: _taxRange,
            inflator: _inflator,
            reward: _reward,
            inflatorTime: _inflatorTime,
            sellTime: _sellTime,
            forkTime: _forkTime,
            tax: _tax
        });
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
        require(list.admin() == address(this), "List admin is not SPOG");
        // add the list to the master list
        masterlist.set(address(list), inMasterList);
        emit NewListAdded(address(list));
    }

    /// @notice Remove a list from the master list of the SPOG
    /// @param list  The list address of the list to be removed
    function removeList(IList list) external onlyVoteGovernor {
        // require that the list is on the master list
        require(masterlist.contains(address(list)), "List is not on the master list");

        // remove the list from the master list
        masterlist.remove(address(list));
        emit ListRemoved(address(list));
    }

    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external onlyVoteGovernor {
        // require that the list is on the master list
        require(masterlist.contains(address(_list)), "List is not on the master list");

        // require that the address is not already on the list
        require(!_list.contains(_address), "Address is already on the list");

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

    /// @notice Create a new proposal
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
        bytes4 executableFuncSelector = _validateProposal(targets, values, calldatas);

        // For all the operations pay flat fee, except emergency remove fee
        if (executableFuncSelector == this.emergencyRemove.selector) {
            _pay(EMERGENCY_REMOVE_TAX_MULTIPLIER * spogData.tax);
        } else {
            _pay(spogData.tax);
        }

        uint256 proposalId = voteGovernor.propose(targets, values, calldatas, description);

        // If we request to change config parameter, value governance should vote too
        if (executableFuncSelector == this.change.selector) {
            uint256 valueProposalId = valueGovernor.propose(targets, values, calldatas, description);
            // TODO: remove it, make them diffent + mapping?
            assert(valueProposalId == proposalId);

            emit NewDoubleQuorumProposal(proposalId);
        } else {
            emit NewProposal(proposalId);
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
        bytes4 executableFuncSelector = _validateProposal(targets, values, calldatas);
        uint256 proposalId = voteGovernor.hashProposal(targets, values, calldatas, descriptionHash);

        // Check that both value and vote governance approved parameter change
        if (executableFuncSelector == this.change.selector) {
            if (valueGovernor.state(proposalId) != ISPOGGovernor.ProposalState.Succeeded) {
                revert("Value governor did not approve the proposal");
            }
        }

        voteGovernor.execute(targets, values, calldatas, descriptionHash);
        return proposalId;
    }

    // ********** Utility FUNCTIONS ********** //
    function tokenInflationCalculation() public view returns (uint256) {
        if (msg.sender == address(voteGovernor)) {
            uint256 votingTokenTotalSupply = IERC20(voteGovernor.votingToken()).totalSupply();
            uint256 inflator = spogData.inflator;

            return (votingTokenTotalSupply * inflator) / 100;
        }

        return 0;
    }

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }

    // ********** PRIVATE Function ********** //

    /// @notice pay tax from the caller to the SPOG
    /// @param _amount The amount to be transferred
    function _pay(uint256 _amount) private {
        // require that the caller pays the tax
        require(_amount >= spogData.tax, "Caller must pay tax to call this function");
        // transfer the amount from the caller to the SPOG
        spogData.cash.safeTransferFrom(msg.sender, address(vault), _amount);
    }

    function _removeFromList(address _address, IList _list) private {
        // require that the list is on the master list
        require(masterlist.contains(address(_list)), "List is not on the master list");

        // require that the address is on the list
        require(_list.contains(_address), "Address is not on the list");

        // remove the address from the list
        _list.remove(_address);
    }

    function _isSupportedFuncSelector(bytes4 _selector) private pure returns (bool) {
        // @note To save gas order checks by the probability of being called from highest to lowest,
        // `append` will be the most common method, and `change` - the least common
        return _selector == this.append.selector || _selector == this.changeTax.selector
            || _selector == this.remove.selector || _selector == this.addNewList.selector
            || _selector == this.removeList.selector || _selector == this.change.selector
            || _selector == this.emergencyRemove.selector;
    }

    function _validateProposal(address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
        private
        view
        returns (bytes4)
    {
        // allow only 1 SPOG change with no value per proposal at a time
        require(targets.length == 1, "Only 1 change per proposal");
        require(targets[0] == address(this), "Only SPOG can be target");
        require(values[0] == 0, "No ETH value should be passed");

        bytes4 executableFuncSelector = bytes4(calldatas[0]);
        require(_isSupportedFuncSelector(executableFuncSelector), "Method is not supported");

        return executableFuncSelector;
    }

    fallback() external {
        revert("SPOG: non-existent function");
    }
}
