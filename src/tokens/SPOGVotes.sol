// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "src/interfaces/tokens/ISPOGVotes.sol";

/// @title SPOGVotes: voting token for the SPOG governor
contract SPOGVotes is ERC20Votes, Ownable, ISPOGVotes {
    /// @notice Constructs governance voting token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol) Ownable() ERC20(name, symbol) ERC20Permit(name) {}

    /// @notice Restricts minting to address with MINTER_ROLE
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Allows deployment to set initial delegate. After deployment nothing calls this.
    /// @param delegator The address to delegate for
    /// @param delegatee The address to delegate to
    function setInitialDelegate(address delegator, address delegatee) public virtual override onlyOwner {
        _delegate(delegator, delegatee);
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

    function owner() public view virtual override(Ownable, ISPOGVotes) returns (address) {
        return super.owner();
    }

    function renounceOwnership() public virtual override(Ownable, ISPOGVotes) onlyOwner {
        super.renounceOwnership();
    }

    function transferOwnership(address newOwner) public virtual override(Ownable, ISPOGVotes) onlyOwner {
        super.transferOwnership(newOwner);
    }
}
