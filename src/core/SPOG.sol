// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC165, IERC20 } from "../interfaces/ImportedInterfaces.sol";
import { IList } from "../interfaces/periphery/IList.sol";
import { IProtocolConfigurator } from "../interfaces/IProtocolConfigurator.sol";
import { ISPOG } from "../interfaces/ISPOG.sol";
import { ISPOGGovernor } from "../interfaces/ISPOGGovernor.sol";
import { ISPOGVault } from "../interfaces/periphery/ISPOGVault.sol";
import { IVALUE, IVOTE } from "../interfaces/ITokens.sol";

import { EnumerableMap, ERC165, SafeERC20 } from "../ImportedContracts.sol";
import { ProtocolConfigurator } from "../config/ProtocolConfigurator.sol";

/// @title SPOG
/// @notice Contracts for governing lists and managing communal property through token voting
/// @dev Reference: https://github.com/MZero-Labs/SPOG-Spec/blob/main/README.md
/// @notice SPOG, "Simple Participation Optimized Governance"
/// @notice SPOG is used for permissioning actors and optimized for token holder participation
contract SPOG is ProtocolConfigurator, ERC165, ISPOG {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct Configuration {
        address payable governor;
        address vault;
        address cash;
        uint256 tax;
        uint256 taxLowerBound;
        uint256 taxUpperBound;
        uint256 inflator;
        uint256 valueFixedInflation;
    }

    /// @dev Indicator that list is in master list
    uint256 private constant _inMasterList = 1;

    /// TODO find the right one for better precision
    uint256 private constant _INFLATOR_SCALE = 100;

    /// @notice Vault for value holders assets
    address public immutable vault;

    /// @notice Cash token used for proposal fee payments
    address public immutable cash;

    /// @notice Fixed inflation rewards per epoch for value holders
    uint256 public immutable valueFixedInflation;

    /// @notice Inflation rate per epoch for vote holders
    uint256 public immutable inflator;

    /// @notice Governor, upgradable via `reset` by value holders
    address public governor;

    /// @notice Tax value for proposal cash fee
    uint256 public tax;

    /// @notice Tax range: lower bound for proposal cash fee
    uint256 public taxLowerBound;

    /// @notice Tax range: upper bound for proposal cash fee
    uint256 public taxUpperBound;

    /// @dev List of addresses that are part of the masterlist
    /// @dev (address => uint256) 0 = not in masterlist, 1 = in masterlist
    EnumerableMap.AddressToUintMap private _masterlist;

    /// @dev Modifier checks if caller is a governor address
    modifier onlyGovernance() {
        if (msg.sender != governor) revert OnlyGovernor();

        _;
    }

    /// @notice Constructs a new SPOG instance
    /// @param config The configuration data for the SPOG
    constructor(Configuration memory config) {
        // Sanity checks
        if (config.governor == address(0)) revert ZeroGovernorAddress();
        if (config.vault == address(0)) revert ZeroVaultAddress();
        if (config.cash == address(0)) revert ZeroCashAddress();
        if (config.tax == 0) revert ZeroTax();
        if (config.tax < config.taxLowerBound || config.tax > config.taxUpperBound) revert TaxOutOfRange();
        if (config.inflator == 0) revert ZeroInflator();
        if (config.valueFixedInflation == 0) revert ZeroValueInflation();

        // Set configuration data
        governor = config.governor;

        // Initialize governor
        ISPOGGovernor(governor).initializeSPOG(address(this));

        vault = config.vault;
        cash = config.cash;
        tax = config.tax;
        taxLowerBound = config.taxLowerBound;
        taxUpperBound = config.taxUpperBound;
        inflator = config.inflator;
        valueFixedInflation = config.valueFixedInflation;
    }

    /// @notice Add a new list to the master list of the SPOG
    /// @param list The list address of the list to be added
    function addList(address list) external onlyGovernance {
        if (IList(list).admin() != address(this)) revert ListAdminIsNotSPOG();

        // add the list to the master list
        _masterlist.set(list, _inMasterList);

        emit ListAdded(list, IList(list).name());
    }

    /// @notice Append an address to a list
    /// @param list The list to which the address will be appended
    /// @param account The address to be appended to the list
    function append(address list, address account) public onlyGovernance {
        if (!_masterlist.contains(list)) revert ListIsNotInMasterList();

        // add the address to the list
        IList(list).add(account);

        emit AddressAppendedToList(list, account);
    }

    /// @notice Remove an address from a list
    /// @param list The list from which the address will be removed
    /// @param account The address to be removed from the list
    function remove(address list, address account) public onlyGovernance {
        if (!_masterlist.contains(list)) revert ListIsNotInMasterList();

        // remove the address from the list
        IList(list).remove(account);

        emit AddressRemovedFromList(list, account);
    }

    /// @notice Change the protocol configs
    /// @param configName The name of the config contract to be changed
    /// @param configAddress The address of the new config contract
    /// @param interfaceId The interface identifier, as specified in ERC-165
    function changeConfig(
        bytes32 configName,
        address configAddress,
        bytes4 interfaceId
    ) public override(IProtocolConfigurator, ProtocolConfigurator) onlyGovernance {
        super.changeConfig(configName, configAddress, interfaceId);
    }

    /// @notice Emergency version of existing methods
    /// @param emergencyType The type of emergency method to be called (See enum in ISPOG)
    /// @param callData The data to be used for the target method
    /// @dev Emergency methods are encoded much like change proposals
    // TODO: IMPORTANT: right now voting period and logic is the same as for other functions
    // TODO: IMPORTANT: implement immediate remove
    function emergency(uint8 emergencyType, bytes calldata callData) external onlyGovernance {
        EmergencyType emergencyType_ = EmergencyType(emergencyType);

        emit EmergencyExecuted(emergencyType, callData);

        if (emergencyType_ == EmergencyType.Remove) {
            (address list, address account) = abi.decode(callData, (address, address));
            remove(list, account);
            return;
        }

        if (emergencyType_ == EmergencyType.Append) {
            (address list, address account) = abi.decode(callData, (address, address));
            append(list, account);
            return;
        }

        if (emergencyType_ == EmergencyType.ChangeConfig) {
            (bytes32 configName, address configAddress, bytes4 interfaceId) = abi.decode(
                callData,
                (bytes32, address, bytes4)
            );

            super.changeConfig(configName, configAddress, interfaceId);
            return;
        }

        revert EmergencyMethodNotSupported();
    }

    /// @notice Reset current governor, special value governance method
    /// @param newGovernor The address of the new governor
    function reset(address newGovernor) external onlyGovernance {
        // TODO: check that newGovernor implements SPOGGovernor interface, ERC165 ?
        governor = newGovernor;

        // Important: initialize SPOG address in the new vote governor
        ISPOGGovernor(governor).initializeSPOG(address(this));

        // Take snapshot of value token balances at the moment of reset
        // Update reset snapshot id for the voting token
        uint256 resetId = IVALUE(ISPOGGovernor(governor).value()).snapshot();
        IVOTE(ISPOGGovernor(governor).vote()).reset(resetId);

        emit ResetExecuted(newGovernor, resetId);
    }

    /// @notice Change the tax rate which is used to calculate the proposal fee
    /// @param newTax The new tax rate
    function changeTax(uint256 newTax) external onlyGovernance {
        if (newTax < taxLowerBound || newTax > taxUpperBound) revert TaxOutOfRange();

        emit TaxChanged(tax, newTax);

        tax = newTax;
    }

    /// @notice Change the tax range which is used to calculate the proposal fee
    /// @param newTaxLowerBound The new lower bound of the tax range
    /// @param newTaxUpperBound The new upper bound of the tax range
    function changeTaxRange(uint256 newTaxLowerBound, uint256 newTaxUpperBound) external onlyGovernance {
        if (newTaxLowerBound > newTaxUpperBound) revert InvalidTaxRange();

        emit TaxRangeChanged(taxLowerBound, newTaxLowerBound, taxUpperBound, newTaxUpperBound);

        taxLowerBound = newTaxLowerBound;
        taxUpperBound = newTaxUpperBound;
    }

    /// @notice Charge fee for calling a governance function
    /// @param account The address of the caller
    function chargeFee(address account, bytes4 /*func*/) external onlyGovernance returns (uint256) {
        // transfer the amount from the caller to the SPOG
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(cash).safeTransferFrom(account, address(this), tax);

        // approve amount to be sent to the vault
        IERC20(cash).approve(vault, tax);

        // deposit the amount to the vault
        uint256 epoch = ISPOGGovernor(governor).currentEpoch();
        ISPOGVault(vault).deposit(epoch, cash, tax);

        emit ProposalFeeCharged(account, epoch, tax);

        return tax;
    }

    /// @notice Getter for finding whether a list is in a masterlist
    /// @param list The list address to check
    /// @return Whether the list is in the masterlist
    function isListInMasterList(address list) external view returns (bool) {
        return _masterlist.contains(list);
    }

    /// @notice Check is proposed change is supported by governance
    /// @param selector The function selector to check
    /// @return Whether the function is supported by governance
    function isGovernedMethod(bytes4 selector) external pure returns (bool) {
        /// @dev ordered by frequency of usage
        return
            selector == this.append.selector ||
            selector == this.addList.selector ||
            selector == this.changeConfig.selector ||
            selector == this.remove.selector ||
            selector == this.changeTax.selector ||
            selector == this.changeTaxRange.selector ||
            selector == this.emergency.selector ||
            selector == this.reset.selector;
    }

    /// @dev check SPOG interface support
    /// @param interfaceId The interface ID to check
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev
    function getInflationReward(uint256 amount) external view returns (uint256) {
        // TODO: prevent overflow, precision loss ?
        return (amount * inflator) / _INFLATOR_SCALE;
    }
}
