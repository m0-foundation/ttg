// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ISPOGVote} from "src/interfaces/ISPOGVote.sol";

/// @title SPOGVote: token used to vote on a SPOG
contract SPOGVote is ERC20Votes, ISPOGVote {
    address public spogAddress;

    /// @dev Initializes the contract by creating the token as well as the default admin role and the SPOG role
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {}

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external {
        require(spogAddress == address(0), "SPOGVote: spogAddress already set");
        spogAddress = _spogAddress;
    }

    /// @dev Restricts minting to the SPOG. Cannot mint more than the max cap
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public {
        require(msg.sender == spogAddress, "SPOGVote: only SPOG can mint");
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
