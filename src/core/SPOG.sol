// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

import {IList} from "src/interfaces/IList.sol";

import {ISPOG} from "src/interfaces/ISPOG.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

import {IVoteToken} from "src/interfaces/tokens/IVoteToken.sol";
import {IValueToken} from "src/interfaces/tokens/IValueToken.sol";

import {IProtocolConfigurator} from "src/interfaces/IProtocolConfigurator.sol";
import {ProtocolConfigurator} from "src/config/ProtocolConfigurator.sol";

import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {SPOGGovernor} from "src/core/governor/SPOGGovernor.sol";

/// @title SPOG
/// @dev Contracts for governing lists and managing communal property through token voting.
/// @dev Reference: https://github.com/TheThing0/SPOG-Spec/blob/main/README.md
/// @notice SPOG, "Simple Participation Optimized Governance," is a governance mechanism that uses token voting to maintain lists and manage communal property.
/// @notice SPOG is used for **permissioning actors**  and optimized for token holder participation.
contract SPOG is ISPOG, ProtocolConfigurator, ERC165 {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct Configuration {
        address payable governor;
        address voteVault;
        address valueVault;
        address cash;
        uint256 tax;
        uint256 taxLowerBound;
        uint256 taxUpperBound;
        uint256 inflator;
        uint256 valueFixedInflation;
    }

    /// @notice Indicator that list is in master list
    uint256 private constant inMasterList = 1;

    /// @notice Multiplier in cash for `emergency` proposal
    uint256 public constant EMERGENCY_TAX_MULTIPLIER = 12;

    /// @notice Multiplier in cash for `reset` proposal
    uint256 public constant RESET_TAX_MULTIPLIER = 12;

    /// @notice Vault for vote holders vote and value inflation rewards
    IVoteVault public immutable voteVault;

    /// @notice Vault for value holders assets
    IValueVault public immutable valueVault;

    /// @notice Cash token used for proposal fee payments
    IERC20 public immutable cash;

    /// @notice Fixed inflation rewards per epoch for value holders
    uint256 public immutable valueFixedInflation;

    /// @notice Inflation rate per epoch for vote holders
    uint256 public immutable inflator;

    /// @notice Governor, upgradable via `reset` by value holders
    SPOGGovernor public governor;

    /// @notice Tax value for proposal cash fee
    uint256 public tax;

    /// @notice Tax range: lower bound for proposal cash fee
    uint256 public taxLowerBound;

    /// @notice Tax range: upper bound for proposal cash fee
    uint256 public taxUpperBound;

    /// @notice List of addresses that are part of the masterlist
    // Masterlist declaration. address => uint256. 0 = not in masterlist, 1 = in masterlist
    EnumerableMap.AddressToUintMap private _masterlist;

    /// @notice Indicator if token rewards were minted for an epoch,
    /// @dev (epoch number => bool)
    mapping(uint256 => bool) private _epochRewardsMinted;

    modifier onlyGovernance() {
        if (msg.sender != address(governor)) revert OnlyGovernor();

        _;
    }

    /// @notice Create a new SPOG instance
    /// @param config The configuration data for the SPOG
    constructor(Configuration memory config) {
        // Sanity checks
        if (config.governor == address(0)) revert ZeroGovernorAddress();
        if (config.voteVault == address(0) || config.valueVault == address(0)) revert ZeroVaultAddress();
        if (config.cash == address(0)) revert ZeroCashAddress();
        if (config.tax == 0) revert ZeroTax();
        if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        if (config.inflator == 0) revert ZeroInflator();
        if (config.valueFixedInflation == 0) revert ZeroValueInflation();

        // Set configuration data
        governor = SPOGGovernor(config.governor);
        // Initialize governor
        governor.initSPOGAddress(address(this));

        voteVault = IVoteVault(config.voteVault);
        valueVault = IValueVault(config.valueVault);
        cash = IERC20(config.cash);
        tax = config.tax;
        taxLowerBound = config.taxLowerBound;
        taxUpperBound = config.taxUpperBound;
        inflator = config.inflator;
        valueFixedInflation = config.valueFixedInflation;
    }

    /// @notice Getter for finding whether a list is in a masterlist
    /// @param list The list address to check
    /// @return Whether the list is in the masterlist
    function isListInMasterList(address list) external view override returns (bool) {
        return _masterlist.contains(list);
    }

    /*//////////////////////////////////////////////////////////////
                            MASTERLIST GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a new list to the master list of the SPOG
    /// @param list The list address of the list to be added
    function addNewList(address list) external override onlyGovernance {
        if (IList(list).admin() != address(this)) revert ListAdminIsNotSPOG();

        // add the list to the master list
        _masterlist.set(list, inMasterList);
        emit NewListAdded(list);
    }

    /// @notice Append an address to a list
    /// @param list The list to which the address will be appended
    /// @param account The address to be appended to the list
    function append(address list, address account) public override onlyGovernance {
        // require that the list is on the master list
        if (!_masterlist.contains(list)) revert ListIsNotInMasterList();

        // add the address to the list
        IList(list).add(account);

        emit AddressAppendedToList(list, account);
    }

    /// @notice Remove an address from a list
    /// @param list The list from which the address will be removed
    /// @param account The address to be removed from the list
    function remove(address list, address account) public override onlyGovernance {
        // require that the list is on the master list
        if (!_masterlist.contains(list)) revert ListIsNotInMasterList();

        // remove the address from the list
        IList(list).remove(account);

        emit AddressRemovedFromList(list, account);
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId)
        public
        override(IProtocolConfigurator, ProtocolConfigurator)
        onlyGovernance
    {
        super.changeConfig(configName, configAddress, interfaceId);
    }

    /// @notice Emergency version of existing methods
    /// @param emergencyType The type of emergency method to be called (See enum in ISPOG)
    /// @param callData The data to be used for the target method
    /// @dev Emergency methods are encoded much like change proposals
    // TODO: IMPORTANT: right now voting period and logic is the same as for other functions
    // TODO: IMPORTANT: implement immediate remove
    function emergency(uint8 emergencyType, bytes calldata callData) external override onlyGovernance {
        EmergencyType _emergencyType = EmergencyType(emergencyType);

        if (_emergencyType == EmergencyType.Remove) {
            (address list, address account) = abi.decode(callData, (address, address));
            remove(list, account);
        } else if (_emergencyType == EmergencyType.Append) {
            (address list, address account) = abi.decode(callData, (address, address));
            append(list, account);
        } else if (_emergencyType == EmergencyType.ChangeConfig) {
            (bytes32 configName, address configAddress, bytes4 interfaceId) =
                abi.decode(callData, (bytes32, address, bytes4));
            super.changeConfig(configName, configAddress, interfaceId);
        } else {
            revert EmergencyMethodNotSupported();
        }

        emit EmergencyExecuted(emergencyType, callData);
    }

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

    function changeTax(uint256 newTax) external onlyGovernance {
        if (newTax < taxLowerBound || newTax > taxUpperBound) revert TaxOutOfRange();

        emit TaxChanged(tax, newTax);
        tax = newTax;
    }

    function changeTaxRange(uint256 newTaxLowerBound, uint256 newTaxUpperBound) external onlyGovernance {
        // TODO: add adequate sanity checks
        emit TaxRangeChanged(taxLowerBound, newTaxLowerBound, taxUpperBound, newTaxUpperBound);

        taxLowerBound = newTaxLowerBound;
        taxUpperBound = newTaxUpperBound;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTION
    //////////////////////////////////////////////////////////////*/

    function isGovernedMethod(bytes4 selector) external view returns (bool) {
        // TODO: order by frequence of usage
        if (selector == this.append.selector) return true;
        if (selector == this.changeTax.selector) return true;
        if (selector == this.changeTaxRange.selector) return true;
        if (selector == this.remove.selector) return true;
        if (selector == this.addNewList.selector) return true;
        if (selector == this.emergency.selector) return true;
        if (selector == this.reset.selector) return true;
        if (selector == this.changeConfig.selector) return true;
        return false;
    }

    function getFee(bytes4 funcSelector) public view returns (uint256, address) {
        uint256 fee;
        // Pay flat fee for all the operations except emergency remove and reset
        if (funcSelector == this.emergency.selector) {
            fee = EMERGENCY_TAX_MULTIPLIER * tax;
        } else if (funcSelector == this.reset.selector) {
            fee = RESET_TAX_MULTIPLIER * tax;
        } else {
            fee = tax;
        }

        return (fee, address(cash));
    }

    /// @notice sell unclaimed $vote tokens
    /// @param epoch The epoch for which to sell unclaimed $vote tokens
    function sellInactiveVoteInflation(uint256 epoch) public {
        voteVault.sellInactiveVoteInflation(epoch, address(cash), governor.votingPeriod());
    }

    /// @notice returns number of vote token rewards for an epoch with active proposals
    // TODO: fix `totalSupply` here and denominator here
    function voteTokenInflationPerEpoch(uint256 epoch) public view returns (uint256) {
        return (governor.vote().totalSupply() * inflator) / 100;
    }

    /// @notice returns number of value token rewards for an epoch with active proposals
    function valueTokenInflationPerEpoch() public view returns (uint256) {
        return valueFixedInflation;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }

    fallback() external {
        revert("SPOG: non-existent function");
    }
}
