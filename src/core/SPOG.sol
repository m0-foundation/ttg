// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {SPOGSettable} from "src/core/SPOGSettable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";

import {IList} from "src/interfaces/IList.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/// @title SPOG
/// @dev Contracts for governing lists and managing communal property through token voting.
/// @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
/// @notice A SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A SPOG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.
contract SPOG is ISPOG, SPOGSettable, ERC165 {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    address public immutable vault;
    uint256 private constant inMasterList = 1;

    // List of addresses that are part of the masterlist
    // Masterlist declaration. address => uint256. 0 = not in masterlist, 1 = in masterlist
    EnumerableMap.AddressToUintMap private masterlist;

    /// @notice Create a new SPOG
    /// @param _initSPOGData The data used to initialize spogData
    /// @param _vault The address of the `Vault` contract
    /// @param _voteTime The duration of a voting epoch in blocks
    /// @param _forkTime The duration that $VALUE holders have to choose a fork
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _govSPOGVote The address of the `GovSPOG` which $VOTE token is used for voting
    /// @param _govSPOGValue The address of the `GovSPOG` which $VALUE token is used for voting
    constructor(
        bytes memory _initSPOGData,
        address _vault,
        uint256 _voteTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        IGovSPOG _govSPOGVote,
        IGovSPOG _govSPOGValue
    )
        SPOGSettable(
            _govSPOGVote,
            _govSPOGValue,
            _voteTime,
            _forkTime,
            _voteQuorum,
            _valueQuorum
        )
    {
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
            uint256 _tax
        ) = abi.decode(
                _initSPOGData,
                (
                    address,
                    uint256[2],
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256
                )
            );

        spogData = SPOGData({
            cash: IERC20(_cash),
            taxRange: _taxRange,
            inflator: _inflator,
            reward: _reward,
            inflatorTime: _inflatorTime,
            sellTime: _sellTime,
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
    function addNewList(IList list) external onlyGovSPOGVote {
        require(list.admin() == address(this), "List admin is not SPOG");
        // add the list to the master list
        masterlist.set(address(list), inMasterList);
        emit NewListAdded(address(list));
    }

    /// @notice Remove a list from the master list of the SPOG
    /// @param list  The list address of the list to be removed
    function removeList(IList list) external onlyGovSPOGVote {
        // require that the list is on the master list
        require(
            masterlist.contains(address(list)),
            "List is not on the master list"
        );

        // remove the list from the master list
        masterlist.remove(address(list));
        emit ListRemoved(address(list));
    }

    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external onlyGovSPOGVote {
        // require that the list is on the master list
        require(
            masterlist.contains(address(_list)),
            "List is not on the master list"
        );

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
    function remove(address _address, IList _list) external onlyGovSPOGVote {
        // require that the list is on the master list
        require(
            masterlist.contains(address(_list)),
            "List is not on the master list"
        );

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
    function emergencyRemove(
        address _address,
        IList _list
    ) external onlyGovSPOGVote {
        _pay(spogData.tax * 12);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "remove(address,IList)",
            _address,
            _list
        );

        string memory description = "Emergency Remove address from list";

        uint256 proposalId = govSPOGVote.propose(
            targets,
            values,
            calldatas,
            description
        );

        emit NewProposal(proposalId);
    }

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(ISPOG).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Create a new proposal
    /// @dev `propose` function of the `Governor` contract
    /// @param govSPOG The SPOG governance contract. Either `govSPOGVote` or `govSPOGValue`
    /// @param targets The targets of the proposal
    /// @param values The values of the proposal
    /// @param calldatas The calldatas of the proposal
    /// @param description The description of the proposal
    /// @return proposalId The ID of the proposal
    function propose(
        IGovSPOG govSPOG,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        // require that the caller pays the tax to propose
        _pay(spogData.tax); // TODO: check for tax for emergency remove proposals

        uint256 proposalId = govSPOG.propose(
            targets,
            values,
            calldatas,
            description
        );
        emit NewProposal(proposalId);

        return proposalId;
    }

    function tokenInflationCalculation() public view returns (uint256) {
        if (msg.sender == address(govSPOGVote)) {
            uint256 votingTokenTotalSupply = IERC20(govSPOGVote.votingToken())
                .totalSupply();
            uint256 inflator = spogData.inflator;

            return (votingTokenTotalSupply * inflator) / 100;
        }

        return 0;
    }

    // ********** PRIVATE Function ********** //

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
}
