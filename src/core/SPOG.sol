// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IList} from "src/interfaces/IList.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

import {ISPOG} from "src/interfaces/ISPOG.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

import {SPOGStorage, SPOGGovernor} from "src/core/SPOGStorage.sol";
import {IVoteToken} from "src/interfaces/tokens/IVoteToken.sol";
import {IValueToken} from "src/interfaces/tokens/IValueToken.sol";

import {IProtocolConfigurator} from "src/interfaces/IProtocolConfigurator.sol";
import {ProtocolConfigurator} from "src/config/ProtocolConfigurator.sol";

import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";

/// @title SPOG
/// @dev Contracts for governing lists and managing communal property through token voting.
/// @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
/// @notice A SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A SPOG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.
contract SPOG is ProtocolConfigurator, SPOGStorage, ERC165 {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // vault for vote holders voting inflation rewards
    IVoteVault public immutable voteVault;
    // vault for value holders assets rewards
    IValueVault public immutable valueVault;

    // List of methods that can be executed by SPOG governance
    mapping(bytes4 => bool) public governedMethods;

    uint256 private constant inMasterList = 1;
    uint256 public constant EMERGENCY_REMOVE_TAX_MULTIPLIER = 12;
    uint256 public constant RESET_TAX_MULTIPLIER = 12;

    // List of addresses that are part of the masterlist
    // Masterlist declaration. address => uint256. 0 = not in masterlist, 1 = in masterlist
    EnumerableMap.AddressToUintMap private masterlist;

    // Indicator that token rewards were already minted for an epoch, epoch number => bool
    mapping(uint256 => bool) private epochRewardsMinted;

    /// @notice Create a new SPOG
    /// @param _initSPOGData The data used to initialize spogData
    /// @param _voteVault The address of the `Vault` contract for vote holders
    /// @param _valueVault The address of the `Vault` contract for value holders
    /// @param _time The duration of a voting epochs for governors and auctions in blocks
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _valueFixedInflationAmount The fixed inflation amount for the $VALUE token
    /// @param _governor The address of the `SPOGGovernor`
    constructor(
        bytes memory _initSPOGData,
        IVoteVault _voteVault,
        IValueVault _valueVault,
        uint256 _time,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _valueFixedInflationAmount,
        SPOGGovernor _governor
    ) SPOGStorage(_initSPOGData, _governor, _time, _voteQuorum, _valueQuorum, _valueFixedInflationAmount) {
        if (_voteVault == IVoteVault(address(0)) || _valueVault == IValueVault(address(0))) {
            revert ISPOG.VaultAddressCannotBeZero();
        }

        voteVault = _voteVault;
        valueVault = _valueVault;

        _initGovernedMethods();
    }

    /// @dev Getter for finding whether a list is in a masterlist
    /// @return Whether the list is in the masterlist
    function isListInMasterList(address list) external view override returns (bool) {
        return masterlist.contains(list);
    }

    /*//////////////////////////////////////////////////////////////
                            MASTERLIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // functions for adding lists to masterlist and appending/removing addresses to/from lists through VOTE

    /// @notice Add a new list to the master list of the SPOG
    /// @param list The list address of the list to be added
    function addNewList(IList list) external override onlyGovernance {
        if (list.admin() != address(this)) {
            revert ListAdminIsNotSPOG();
        }
        // add the list to the master list
        masterlist.set(address(list), inMasterList);
        emit NewListAdded(address(list));
    }

    /// @notice Append an address to a list
    /// @param _address The address to be appended to the list
    /// @param _list The list to which the address will be appended
    function append(address _address, IList _list) external override onlyGovernance {
        // require that the list is on the master list
        if (!masterlist.contains(address(_list))) {
            revert ListIsNotInMasterList();
        }

        // append the address to the list
        _list.add(_address);
        emit AddressAppendedToList(address(_list), _address);
    }

    // create function to remove an address from a list
    /// @notice Remove an address from a list
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    function remove(address _address, IList _list) external override onlyGovernance {
        _removeFromList(_address, _list);
        emit AddressRemovedFromList(address(_list), _address);
    }

    // create function to remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @notice Remove an address from a list immediately upon reaching a `VOTE QUORUM`
    /// @param _address The address to be removed from the list
    /// @param _list The list from which the address will be removed
    // TODO: IMPORTANT: right now voting period and logic is the same as for otherfunctions
    // TODO: IMPORTANT: implement immediate remove
    function emergencyRemove(address _address, IList _list) external override onlyGovernance {
        _removeFromList(_address, _list);
        emit EmergencyAddressRemovedFromList(address(_list), _address);
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIG GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId)
        public
        override(IProtocolConfigurator, ProtocolConfigurator)
        onlyGovernance
    {
        return super.changeConfig(configName, configAddress, interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE INTERFACE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // reset current vote governance, only value governor can do it
    // @param newVoteGovernor The address of the new vote governance
    function reset(SPOGGovernor newGovernor) external onlyGovernance {
        // TODO: check that newVoteGovernor implements SPOGGovernor interface, ERC165 ?

        IVoteToken newVoteToken = IVoteToken(address(newGovernor.vote()));
        IValueToken valueToken = IValueToken(address(newGovernor.value()));
        if (address(valueToken) != newVoteToken.valueToken()) revert ValueTokenMistmatch();

        // Update vote governance in the vault
        // TODO: how to avoid this ?
        IVoteVault(voteVault).updateGovernor(newGovernor);

        governor = newGovernor;
        // Important: initialize SPOG address in the new vote governor
        governor.initSPOGAddress(address(this));

        // Take snapshot of value token balances at the moment of reset
        // Update reset snapshot id for the voting token
        uint256 resetSnapshotId = valueToken.snapshot();
        newVoteToken.initReset(resetSnapshotId);

        emit SPOGResetExecuted(address(newVoteToken), address(newGovernor));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTION
    //////////////////////////////////////////////////////////////*/

    function getFee(bytes4 funcSelector) public view returns (uint256, address) {
        uint256 fee;
        // Pay flat fee for all the operations except emergency remove and reset
        if (funcSelector == this.emergencyRemove.selector) {
            fee = EMERGENCY_REMOVE_TAX_MULTIPLIER * spogData.tax;
        } else if (funcSelector == this.reset.selector) {
            fee = RESET_TAX_MULTIPLIER * spogData.tax;
        } else {
            fee = spogData.tax;
        }

        return (fee, address(spogData.cash));
    }

    /// @notice sell unclaimed $vote tokens
    /// @param epoch The epoch for which to sell unclaimed $vote tokens
    function sellInactiveVoteInflation(uint256 epoch) public {
        voteVault.sellInactiveVoteInflation(epoch, address(spogData.cash), governor.votingPeriod());
    }

    /// @notice returns number of vote token rewards for an epoch with active proposals
    // TODO: can we use `totalSupply` here
    function voteTokenInflationPerEpoch() public view returns (uint256) {
        return (governor.vote().totalSupply() * spogData.inflator) / 100;
    }

    /// @notice returns number of value token rewards for an epoch with active proposals
    function valueTokenInflationPerEpoch() public view returns (uint256) {
        return valueFixedInflationAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initGovernedMethods() private {
        // TODO: review if there is better, more efficient way to do it
        governedMethods[this.append.selector] = true;
        governedMethods[this.changeTax.selector] = true;
        governedMethods[this.remove.selector] = true;
        governedMethods[this.addNewList.selector] = true;
        governedMethods[this.change.selector] = true;
        governedMethods[this.emergencyRemove.selector] = true;
        governedMethods[this.reset.selector] = true;
        governedMethods[this.changeConfig.selector] = true;
    }

    function _removeFromList(address _address, IList _list) private {
        // require that the list is on the master list
        if (!masterlist.contains(address(_list))) {
            revert ListIsNotInMasterList();
        }

        // remove the address from the list
        _list.remove(_address);
    }

    /// @notice extract address params from the call data
    /// @param callData The call data with selector in first 4 bytes
    /// @dev used to inspect params before allowing proposal
    function _extractAddressTypeParamsFromCalldata(bytes memory callData)
        internal
        pure
        returns (address targetParams)
    {
        assembly {
            // byte offset to represent function call data. 4 bytes funcSelector plus address 32 bytes
            let offset := 36
            // add offset so we pick from start of address params
            let addressPosition := add(callData, offset)
            // load the address params
            targetParams := mload(addressPosition)
        }
    }

    fallback() external {
        revert("SPOG: non-existent function");
    }
}
