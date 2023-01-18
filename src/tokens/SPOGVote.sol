// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import {ISPOGVote} from "../interfaces/ISPOGVote.sol";

/// @title SPOGVote: token used to vote on a SPOG
contract SPOGVote is ERC20Votes, ISPOGVote, AccessControlEnumerable {
    bytes32 public constant SPOG_ROLE = keccak256("SPOG_ROLE");

    /// @dev Initializes the contract by creating the token as well as the default admin role and the SPOG role
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        // TODO: add require for msg.sender to be the SPOG
        grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(SPOG_ROLE, _msgSender());
    }

    /// @dev Restricts minting to the SPOG. Cannot mint more than the max cap
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyRole(SPOG_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
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
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}
