// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IList} from "./interfaces/IList.sol";
import {List} from "./List.sol";

import {ISPOGVote} from "./interfaces/ISPOGVote.sol";
import {ISPOG} from "./interfaces/ISPOG.sol";

import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title SPOG
 * @dev Contracts for governing lists and managing communal property through token voting.
 * @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
 * @notice A SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A SPOG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.
 */
contract SPOG is ISPOG, ERC165 {
    using SafeERC20 for IERC20;

    struct SPOGData {
        uint256 tax;
        uint256 currentEpoch;
        uint256 currentEpochEnd;
        uint256 valueQuorum;
        uint256 inflatorTime;
        uint256 sellTime;
        uint256 forkTime;
        uint256 inflator;
        uint256 reward;
        uint256[2] taxRange;
        IERC20 cash;
    }
    SPOGData public spogData;

    IGovSPOG public govSPOG;

    // TODO: variable packing for SPOGData: https://dev.to/javier123454321/solidity-gas-optimizations-pt-3-packing-structs-23f4

    // These are set in GovSPOG
    // uint256 public voteQuorum;
    // ISPOGVote public vote;
    // uint256 public voteTime;

    // List of addresses that are part of the masterlist
    mapping(address => bool) public masterlist;

    event NewListAdded(address _list);
    event ListRemoved(address _list);
    event AddressAppendedToList(address _list, address _address);
    event AddressRemovedFromList(address _list, address _address);

    // create constructor to set contract variables with natspec comments
    /// @notice Create a new SPOG
    /// @param _cash The currency accepted for tax payment in the SPOG (must be ERC20)
    /// @param _taxRange The minimum and maximum value of `tax`
    /// @param _inflator The percentage supply increase in $VOTE for each voting epoch
    /// @param _reward The number of $VALUE to be distributed in each voting epoch
    /// @param _voteTime The duration of a voting epoch in blocks
    /// @param _inflatorTime The duration of an auction if $VOTE is inflated (should be less than `VOTE TIME`)
    /// @param _sellTime The duration of an auction if `SELL` is called
    /// @param _forkTime The duration that $VALUE holders have to choose a fork
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _tax The cost (in `cash`) to call various functions
    /// @param _govSPOG The address of the `GovSPOG` contract
    constructor(
        address _cash,
        uint256[2] memory _taxRange,
        uint256 _inflator,
        uint256 _reward,
        uint256 _voteTime,
        uint256 _inflatorTime,
        uint256 _sellTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _tax,
        IGovSPOG _govSPOG
    ) {
        // TODO: add require statements for variables
        spogData.cash = IERC20(_cash);
        spogData.taxRange[0] = _taxRange[0];
        spogData.taxRange[1] = _taxRange[1];
        spogData.inflator = _inflator;
        spogData.reward = _reward;
        spogData.inflatorTime = _inflatorTime;
        spogData.sellTime = _sellTime;
        spogData.forkTime = _forkTime;
        spogData.valueQuorum = _valueQuorum;
        spogData.tax = _tax;

        // govSPOG settings
        govSPOG = _govSPOG;

        // Set in GovSPOG
        govSPOG.initSPOGAddress(address(this));
        govSPOG.updateQuorumNumerator(_voteQuorum);
        govSPOG.updateVotingTime(_voteTime);

        ISPOGVote(address(govSPOG.spogVote())).initSPOGAddress(address(this));

        spogData.currentEpoch = 1;
        spogData.currentEpochEnd = block.number + _voteTime;
    }

    modifier onlyGovernance() {
        require(msg.sender == address(govSPOG), "SPOG: Only GovSPOG");
        _;
    }

    /// @dev Getter for taxRange. It returns the minimum and maximum value of `tax`
    /// @return The minimum and maximum value of `tax`
    function taxRange() external view returns (uint256, uint256) {
        return (spogData.taxRange[0], spogData.taxRange[1]);
    }

    // functions for adding lists to masterlist and appending/removing addresses to/from lists through VOTE

    /// @notice Add a new list to the master list of the SPOG
    function addNewList() external onlyGovernance {
        address list = address(new List());
        // add the list to the master list
        masterlist[list] = true;
        emit NewListAdded(list);

        // used for prototype only - remove later
        lists.push(list);
    }

    // create function to remove a list from the master list of the SPOG
    /// @notice Remove a list from the master list of the SPOG
    /// @param _listAddress  The list address of the list to be removed
    function removeList(address _listAddress) external onlyGovernance {
        // require that the list is on the master list
        require(masterlist[_listAddress], "List is not on the master list");

        // remove the list from the master list
        masterlist[_listAddress] = false;
        emit ListRemoved(_listAddress);
    }

    // create function to append an address to a list
    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external onlyGovernance {
        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

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
    function remove(address _address, IList _list) external onlyGovernance {
        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

        // require that the address is on the list
        require(_list.contains(_address), "Address is not on the list");

        // remove the address from the list
        _list.remove(_address);
        emit AddressRemovedFromList(address(_list), _address);
    }

    // create function to remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @notice Remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    function emergencyRemove(address _address, IList _list)
        external
        onlyGovernance
    {
        // TODO: need to come up with a way to pay the tax*12 during emergencyRemove() proposal
        // _pay(spogData.tax * 12);

        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

        // require that the address is on the list
        require(_list.contains(_address), "Address is not on the list");

        // // require that the vote quorum has been reached
        // require(
        //     _voteSucceeded(_proposalId),
        //     "Vote quorum has not been reached for this action"
        // );

        // remove the address from the list
        _list.remove(_address);
        emit AddressRemovedFromList(address(_list), _address);
    }

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == type(ISPOG).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Create a new proposal
    /// @dev `propose` function of the `Governor` contract
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
    ) public returns (uint256) {
        // require that the caller pays the tax to propose
        _pay(spogData.tax); // TODO: check for tax for emergency remove proposals
        return govSPOG.propose(targets, values, calldatas, description);
    }

    // ********** PRIVATE FUNCTIONS ********** //

    /// @notice pay tax from the caller to the SPOG
    /// @param _amount The amount to be transferred
    function _pay(uint256 _amount) private {
        // require that the caller pays the tax
        require(
            _amount >= spogData.tax,
            "Caller must pay tax to call this function"
        );
        // transfer the amount from the caller to the SPOG
        spogData.cash.safeTransferFrom(msg.sender, address(this), _amount);
    }

    fallback() external {
        revert("SPOG: non-existent function");
    }

    /***************************************************/
    /******** Prototype Helpers - NOT FOR PROD ********/
    /*************************************************/

    address[] private lists;

    function getLists() external view returns (address[] memory) {
        return lists;
    }

    function getListLength() external view returns (uint256) {
        return lists.length;
    }

    // helper function to mint VOTE tokens for testing - Not to be used in production
    function mintSpogVotes(
        address spogVoteAddress,
        address _to,
        uint256 _amount
    ) external {
        require(_amount <= 100e18, "Cannot mint more than 100 VOTE tokens");
        ISPOGVote(spogVoteAddress).mint(_to, _amount);
    }
}
