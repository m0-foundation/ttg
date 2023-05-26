// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/interfaces/IProtocolConfigurator.sol";
import "src/interfaces/vaults/IValueVault.sol";
import "src/interfaces/vaults/IVoteVault.sol";

import "src/core/governor/DualGovernor.sol";

interface ISPOG is IProtocolConfigurator, IERC165 {
    enum EmergencyType {
        Remove,
        Append,
        ChangeConfig
    }

    // Events
    event NewListAdded(address indexed list);
    event AddressAppendedToList(address indexed list, address indexed account);
    event AddressRemovedFromList(address indexed list, address indexed account);
    event EmergencyExecuted(uint8 emergencyType, bytes callData);
    event TaxChanged(uint256 oldTax, uint256 newTax);
    event TaxRangeChanged(uint256 oldLowerRange, uint256 newLowerRange, uint256 oldUpperRange, uint256 newUpperRange);
    event ResetExecuted(address indexed newVoteToken, address indexed newGovernor);

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
    function governor() external view returns (DualGovernor);
    function voteVault() external view returns (IVoteVault);
    function valueVault() external view returns (IValueVault);
    function cash() external view returns (IERC20);
    function tax() external view returns (uint256);
    function taxLowerBound() external view returns (uint256);
    function taxUpperBound() external view returns (uint256);
    function inflator() external view returns (uint256);
    function valueFixedInflation() external view returns (uint256);

    // Accepted `proposal` functions
    function addNewList(address list) external;
    function append(address list, address account) external;
    function remove(address list, address account) external;
    function emergency(uint8 emergencyType, bytes calldata callData) external;
    function reset(DualGovernor newGovernor) external;
    function changeTax(uint256 _tax) external;
    function changeTaxRange(uint256 lowerBound, uint256 upperBound) external;

    function isGovernedMethod(bytes4 func) external view returns (bool);
    function chargeFee(address account, bytes4 func) external;
    function inflateRewardTokens() external;

    // List accessor functions
    function isListInMasterList(address list) external view returns (bool);
}
