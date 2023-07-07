// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "src/interfaces/tokens/ISPOGVotes.sol";

abstract contract SPOGVotes is ERC20Permit, AccessControlEnumerable, ISPOGVotes {
    bytes32 public constant override MINTER_ROLE = keccak256("MINTER_ROLE");

    address public override spog;

    /// @notice Constructs governance voting token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        // TODO: Who will be the admin of this contract?
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Sets the spog address. Can only be called once.
    /// @param _spog the address of the spog
    function initializeSPOG(address _spog) external override {
        if (spog != address(0)) revert AlreadyInitialized();

        spog = _spog;
        _setupRole(MINTER_ROLE, _spog);
    }
}
