// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IList} from "./interfaces/IList.sol";

import {ISPOGVote} from "./interfaces/ISPOGVote.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SPOG
 * @dev Contracts for governing lists and managing communal property through token voting.
 * @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
 * @notice A SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A SPOG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.
 */
contract SPOG {
    using SafeERC20 for IERC20;

    // contract variables
    IERC20 public cash;
    uint256 public taxRange;
    uint256 public inflator;
    uint256 public reward;
    uint256 public voteTime;
    uint256 public inflatorTime;
    uint256 public sellTime;
    uint256 public forkTime;
    uint256 public voteQuorum;
    uint256 public valueQuorum;
    uint256 public tax;

    uint256 public currentEpoch;
    uint256 public currentEpochEnd;

    ISPOGVote public vote;

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
    /// @param _voteTime The duration of a voting epoch
    /// @param _inflatorTime The duration of an auction if $VOTE is inflated (should be less than `VOTE TIME`)
    /// @param _sellTime The duration of an auction if `SELL` is called
    /// @param _forkTime The duration that $VALUE holders have to choose a fork
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _tax The cost (in `cash`) to call various functions
    /// @param _vote The token used for voting
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
        ISPOGVote _vote
    ) {
        cash = IERC20(_cash);
        taxRange = _taxRange[0];
        inflator = _inflator;
        reward = _reward;
        voteTime = _voteTime;
        inflatorTime = _inflatorTime;
        sellTime = _sellTime;
        forkTime = _forkTime;
        voteQuorum = _voteQuorum;
        valueQuorum = _valueQuorum;
        tax = _tax;
        vote = _vote;

        currentEpoch = 1;
        currentEpochEnd = block.timestamp + voteTime;
    }

    // functions for adding lists to masterlist and appending/removing addresses to/from lists through VOTE

    /// @notice Add a new list to the master list of the SPOG
    /// @param _id The ID as the list address of the list to be added
    function newList(address _id) external {
        _pay(tax);

        // require that the list is not already on the master list
        require(!masterlist[_id], "List is already on the master list");

        // TODO: require if vote has been passed in the preceding epoch

        // add the list to the master list
        masterlist[_id] = true;
        emit NewListAdded(_id);
    }

    // create function to remove a list from the master list of the SPOG
    /// @notice Remove a list from the master list of the SPOG
    /// @param _id The ID as the list address of the list to be removed
    function removeList(address _id) external {
        _pay(tax);

        // require that the list is on the master list
        require(masterlist[_id], "List is not on the master list");

        // TODO: require if vote has been passed in the preceding epoch

        // remove the list from the master list
        masterlist[_id] = false;
        emit ListRemoved(_id);
    }

    // create function to append an address to a list
    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external {
        _pay(tax);

        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

        // require that the address is not already on the list
        require(!_list.contains(_address), "Address is already on the list");

        // TODO: require if vote has been passed in the preceding epoch

        // append the address to the list
        _list.add(_address);
        emit AddressAppendedToList(address(_list), _address);
    }

    // create function to remove an address from a list
    /// @notice Remove an address from a list
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    function remove(address _address, IList _list) external {
        _pay(tax);

        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

        // require that the address is on the list
        require(_list.contains(_address), "Address is not on the list");

        // TODO: require if vote has been passed in the preceding epoch

        // remove the address from the list
        _list.remove(_address);
        emit AddressRemovedFromList(address(_list), _address);
    }

    // create function to remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @notice Remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    function emergencyRemove(address _address, IList _list) external {
        _pay(tax * 12);

        // require that the list is on the master list
        require(masterlist[address(_list)], "List is not on the master list");

        // require that the address is on the list
        require(_list.contains(_address), "Address is not on the list");

        // require that the vote quorum has been reached
        require(
            voteQuorumReached(), // implement vote quorum reached function
            "Vote quorum has not been reached for this action"
        );

        // remove the address from the list
        _list.remove(_address);
        emit AddressRemovedFromList(address(_list), _address);
    }

    // create function to check if the vote quorum has been reached
    /// @notice Check if the vote quorum has been reached
    /// @return `true` if the vote quorum has been reached, `false` otherwise
    function voteQuorumReached() public view returns (bool) {
        // get the number of votes cast
        uint256 votesCast = votes.length; // TODO: implement votes count

        // get the number of votes required to reach the vote quorum
        uint256 votesRequired = (voteQuorum * vote.totalSupply()) / 100;

        // return whether the vote quorum has been reached
        return votesCast >= votesRequired;
    }

    // ********** PRIVATE FUNCTIONS ********** //

    /// @notice pay tax from the caller to the SPOG
    /// @param _amount The amount to be transferred
    function _pay(uint256 _amount) private {
        // require that the caller pays the tax
        require(_amount == tax, "Caller must pay tax to call this function");
        // transfer the amount from the caller to the SPOG
        cash.safeTransferFrom(msg.sender, address(this), _amount);
    }
}
