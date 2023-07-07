// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/interfaces/IProtocolConfigurator.sol";
import "src/interfaces/ISPOGGovernor.sol";
import "src/interfaces/periphery/ISPOGVault.sol";

interface ISPOG is IProtocolConfigurator, IERC165 {
    // Enums
    enum EmergencyType {
        Remove,
        Append,
        ChangeConfig
    }

    // Events
    event ListAdded(address indexed list);
    event AddressAppendedToList(address indexed list, address indexed account);
    event AddressRemovedFromList(address indexed list, address indexed account);
    event EmergencyExecuted(uint8 emergencyType, bytes callData);
    event TaxChanged(uint256 oldTax, uint256 newTax);
    event TaxRangeChanged(uint256 oldLowerRange, uint256 newLowerRange, uint256 oldUpperRange, uint256 newUpperRange);
    event ResetExecuted(address indexed newGovernor, uint256 indexed resetSnapshotId);

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
    error InvalidTaxRange();

    // Info functions about double governance and SPOG parameters
    function governor() external view returns (ISPOGGovernor);
    function vault() external view returns (ISPOGVault);
    function cash() external view returns (IERC20);
    function tax() external view returns (uint256);
    function taxLowerBound() external view returns (uint256);
    function taxUpperBound() external view returns (uint256);
    function inflator() external view returns (uint256);
    function valueFixedInflation() external view returns (uint256);

    // Accepted `proposal` functions
    function addList(address list) external;
    function append(address list, address account) external;
    function remove(address list, address account) external;
    function emergency(uint8 emergencyType, bytes calldata callData) external;
    function reset(address newGovernor) external;
    function changeTax(uint256 newTax) external;
    function changeTaxRange(uint256 newLowerBound, uint256 newUpperBound) external;

    function isGovernedMethod(bytes4 func) external pure returns (bool);
    function chargeFee(address account, bytes4 func) external;
    // function inflateRewardTokens() external;

    // List accessor functions
    function isListInMasterList(address list) external view returns (bool);
}
