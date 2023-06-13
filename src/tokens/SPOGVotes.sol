// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "src/interfaces/tokens/ISPOGVotes.sol";

/// @title SPOGVotes: voting token for the SPOG governor
contract SPOGVotes is ERC20Votes, AccessControlEnumerable, ISPOGVotes {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public spog;

    // Errors
    error CallerIsNotSPOG();
    error AlreadyInitialized();

    /// @notice Constructs governance voting token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        // TODO: Who will be the admin of this contract?
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Sets the spog address. Can only be called once.
    /// @param _spog the address of the spog
    function initializeSPOG(address _spog) external {
        if (spog != address(0)) revert AlreadyInitialized();

        spog = _spog;
        _setupRole(MINTER_ROLE, _spog);
    }

    /// @notice Restricts minting to address with MINTER_ROLE
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}
